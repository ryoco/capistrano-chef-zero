require "json"
require "sshkit"
require "sshkit/dsl"
include SSHKit::DSL


# TODO
def git_repository(repo, branch, dir)
  execute :rm, "-rf #{dir}"
  execute :git, "clone -b #{branch} '#{repo}' #{dir}"
end

def update_config
  configs = { "cookbook_path" => fetch(:chef_zero_cookbooks_path_list) }
  contents = StringIO.new(configs.each.map { |key, value| "#{key} #{value}"}.join("\n"))
  upload! contents, File.join(fetch(:chef_zero_config_path), "config.rb")
end

def update_cookbooks
  fetch(:chef_zero_cookbooks).values.each do |v|
    git_repository(v[:repository], v[:revision], v[:deploy_dir])
  end
  upload! "#{ fetch(:local_chef_zero_cookbooks) }", "#{ fetch(:chef_zero_path) }", recursive: true
end

def update_roles(role)
  attributes = _generate_chef_type_attributes(role, "role", "Chef:Role", {
    "default_attributes" => fetch(:chef_zero_role_attributes).fetch(role, {}),
    "run_list" => fetch(:chef_zero_role_run_list).fetch(role, [])
  })
  contents = StringIO.new(_json_attributes(attributes))
  upload! contents, File.join(fetch(:chef_zero_roles_path), "#{role}.json")
end

def update_attributes(host)
  attributes = _generate_host_attributes(host, :roles => host.roles_array)
  contents = StringIO.new(_json_attributes(attributes))
  upload! contents, fetch(:chef_zero_attributes_file)
end

def update_environments(environment)
  attributes = _generate_chef_type_attributes(environment, "envitonment", "Chef:Environment", {"default_attributes" => fetch(:chef_zero_environment_attributes)})
  contents = StringIO.new(_json_attributes(attributes))
  upload! contents, File.join(fetch(:chef_zero_environments_path), "#{environment}.json")
end


# merge nested hashes
def _merge_attributes!(a, b)
  f = lambda { |key, val1, val2|
    case val1
    when Array
      val1 + val2
    when Hash
      val1.merge(val2, &f)
    else
      val2
    end
  }
  a.merge!(b, &f)
end

def _json_attributes(x)
  JSON.send(fetch(:chef_zero_pretty_json, true) ? :pretty_generate : :generate, x)
end

def _generate_chef_type_attributes(name, chef_type, json_class, options={})
  attributes = {
    "name" => name,
    "chef_type" => chef_type,
    "json_class" => json_class,
  }
  _merge_attributes!(attributes, options)
  attributes
end

def _generate_host_attributes(host, options={})
  roles = [ options.delete(:roles) ].flatten.compact.uniq

  attributes = {"run_list" => []}

  _merge_attributes!(attributes, {"run_list" => fetch(:chef_zero_run_list)})
  _merge_attributes!(attributes, {"run_list" => roles.map { |role| "role[#{role}]" } }) unless roles.empty?
  _merge_attributes!(attributes, {"run_list" => fetch(:chef_zero_host_run_list).fetch(host, [])})
  attributes
end


desc "Do all tasks."
task :"chef-zero" => "chef-zero:default"
namespace :"chef-zero" do
  desc "Do all "
  task :default do 
    %w{ install
        update
        deploy }.each do |task|
      invoke "chef-zero:#{task}"
    end
  end
  desc "Install chef."
  task :install do
    on release_roles(fetch(:chef_zero_roles)) do
      if !execute(:gem, "list chef -i -v #{fetch(:chef_version)}", raise_on_non_zero_exit: false)
        execute :gem, "install chef -v #{fetch(:chef_version)}"
      end
      # setup directories
      dirs = [ fetch(:chef_zero_path), fetch(:chef_zero_cache_path), fetch(:chef_zero_config_path), fetch(:chef_zero_roles_path), fetch(:chef_zero_environments_path) ].uniq
      execute "mkdir -p #{dirs.map { |x| x.dump }.join(" ")}"
    end
  end
  desc "Update "
  task :update do
    on release_roles(fetch(:chef_zero_roles)) do
      fetch(:chef_zero_cookbooks).each do |k, v|
        if v.key?(:cookbook_name)
          v.merge!(deploy_dir: File.join(fetch(:chef_zero_path), "cookbooks", v[:cookbook_name]))
        else
          append(:chef_zero_cookbooks_path_list, File.join(fetch(:chef_zero_path), k))
          v.merge!(deploy_dir: File.join(fetch(:chef_zero_path), k))
        end
      end
      update_config
      update_cookbooks
      update_environments(fetch(:rails_env))
    end
    on release_roles(fetch(:chef_zero_roles)) do |host|
      host.roles_array.uniq.map { |role| update_roles(role) }
      update_attributes(host)
    end
  end
  desc "Execute chef-client command."
  task :deploy do
    on release_roles(fetch(:chef_zero_roles)) do
      execute :"chef-client", "-z -j #{fetch(:chef_zero_attributes_file)} -c #{fetch(:chef_zero_config_file)} -E #{fetch(:rails_env)}"
    end
  end
end


namespace :load do
  task :defaults do

    set :chef_version, "12.15.19"

    set :chef_zero_roles, fetch(:chef_zero_roles, :all)

    set :local_chef_zero_cookbooks, -> { File.join( Dir.pwd, "config", "cookbooks") }
    set :chef_zero_path, -> { File.join(fetch(:deploy_to), "chef") }
    set :chef_zero_cache_path, -> { File.join(fetch(:chef_zero_path), "cache") }
    set :chef_zero_config_path, -> { File.join(fetch(:chef_zero_path), "config") }
    set :chef_zero_cookbooks_path, -> { File.join(fetch(:chef_zero_path), "cookbooks") }
    set :chef_zero_cookbooks_path_list, -> {[
      fetch(:chef_zero_cookbooks_path),
    ]}
    set :chef_zero_data_bags_path, -> { File.join(cfetch(:chef_zero_path), "data_bags") }
    set :chef_zero_roles_path, -> { File.join(fetch(:chef_zero_path), "roles") }
    set :chef_zero_environments_path, -> { File.join(fetch(:chef_zero_path), "environments") }
    set :chef_zero_config_file, -> { File.join(fetch(:chef_zero_config_path), "config.rb") }
    set :chef_zero_attributes_file, -> { File.join(fetch(:chef_zero_config_path), "config.json") }
    set :chef_zero_attributes, {}
    set :chef_zero_run_list, []
    set :chef_zero_host_attributes, {}
    set :chef_zero_host_run_list, {}
    set :chef_zero_role_attributes, {}
    set :chef_zero_role_run_list, {}

  end
end
