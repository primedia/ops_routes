require 'haml'

module OpsRoutes
  
  class << self
    
    attr_writer :app_name
    attr_accessor :file_root
    
    def config
      yield OpsRoutes if block_given?
    end
    # Heartbeats
    
    def heartbeats
      @heartbeats ||= {}
    end
    
    def add_heartbeat(name, &block)
      heartbeats[name] = block
    end
    
    def check_heartbeat(name = nil)
      if name
        begin
          heartbeats[name.to_sym].call
          return { :status => 200, :text => "#{name} is OK" }
        rescue
          return { :status => 500, :text => "#{name} does not have a heartbeat" }
        end
      else
        return { :status => 200, :text => 'OK' }
      end
    end
    
    # Version page

    def check_version(headers={})
      @headers = headers
      version_template = File.join(File.dirname(__FILE__), 'views', 'version.html.haml')
      Haml::Engine.new(File.read(version_template)).render(self)
    end
    
    def version_or_branch
      @version ||= if File.exists?(version_file)
        File.read(version_file).chomp.gsub('^{}', '')
      elsif environment == 'development' && `git branch` =~ /^\* (.*)$/
        $1
      else
        'Unknown (VERSION file is missing)'
      end
    end
    
    def previous_versions
      return @previous_versions if @previous_versions
      @previous_versions = []
      dirs = Dir.pwd.split('/')
      if dirs.last =~ /^\d+$/
        Dir["../*"].each do |dir|
          next if dir == dirs.last
          version = File.join(dir, 'VERSION')
          revision = File.join(dir, 'REVISION')
          if File.exists?(version) && File.exists?(revision)
            @previous_versions << { :version => File.read(version).chomp.gsub('^{}', ''),
              :revision => File.read(revision).chomp,
              :time => File.stat(revision).mtime }
          end
        end
        @previous_versions.sort!{ |a, b| a[:time] <=> b[:time] }
      end
      @previous_versions
    end

    def version_file
      @version_file ||= File.join(file_root, 'VERSION')
    end
    
    def environment
      ENV['RAILS_ENV']
    end
    
    def deploy_date
      @deploy_date ||= if File.exists?(version_file)
        File.stat(version_file).mtime
      elsif environment == 'development'
        'Live'
      else
        'Unknown (VERSION file is missing)'
      end
    end
    
    def last_commit
      @last_commit ||= if File.exists?(revision_file)
        File.read(revision_file).chomp
      elsif environment == 'development' && `git show` =~ /^commit (.*)$/
        $1
      else
        'Unknown (REVISION file is missing)'
      end
    end
    
    def revision_file
      @revision_file ||= File.join(file_root, 'REVISION')
    end
    
    def hostname
      @hostname ||= `/bin/hostname` || 'Unknown'
    end
    
    def app_name
      @app_name ||= begin
        dirs = Dir.pwd.split('/')
        if dirs.last =~ /^\d+$/
          dirs[-3]
        else
          dirs.last
        end.sub(/\.com$/, '')
      end
    end
    
    def headers
      @headers.select{|k,v| k.match(/^[-A-Z_].*$/) }
    end
    
    def version_link(version)
      "https://github.com/primedia/#{app_name}/tree/#{version}" unless version_or_branch =~ /^Unknown/
    end
    
    def commit_link(commit)
      "https://github.com/primedia/#{app_name}/commit/#{commit}" unless commit =~ /^Unknown/
    end
    
  end
  
end
