#!/usr/bin/env ruby

require 'optparse'
require 'google/api_client'
require 'active_support/all'
require 'memoist'

APPLICATION_NAME    = 'monitoring-google-drive'
APPLICATION_VERSION = '1.0.0'

debug = false

def setup(issuer, owner)
  client = Google::APIClient.new(:application_name    => APPLICATION_NAME,
                                 :application_version => APPLICATION_VERSION)
  key = Google::APIClient::PKCS12.load_key('monitoring-google-drive.p12', 'notasecret')
  client.authorization = Signet::OAuth2::Client.new(
    :token_credential_uri => 'https://accounts.google.com/o/oauth2/token',
    :audience             => 'https://accounts.google.com/o/oauth2/token',
    :scope                => ['https://www.googleapis.com/auth/drive.readonly', 'https://www.googleapis.com/auth/admin.directory.user.readonly'],
    :issuer               => issuer,
    :signing_key          => key,
    :sub                  => owner
  )
  client.authorization.fetch_access_token!

  drive = client.discovered_api('drive', 'v2')
  directory = client.discovered_api('admin', 'directory_v1')

  return client, drive, directory
end

def get_files(client, drive, owner)
  result = client.execute(
    api_method: drive.files.list,
    parameters: {
      maxResults: 10000,
      q: owner.nil? ? '' : sprintf("'%s' in owners", owner)
    },
  )
  # jj result.data.to_hash
  result
end

def get_all_users(client, directory)
  result = client.execute(
    api_method: directory.users.list,
    :parameters => {
      :customer => 'my_customer',
      :maxResults => 500,
      :orderBy => 'email'
    }
  )
  result.data.users
end

class DirectoryCache
  extend Memoist
  def initialize(client, drive)
    @client = client
    @drive = drive
  end

  def get_dir(parent_id)
    @client.execute(
      :api_method => @drive.files.get,
      :parameters => { 'fileId' => parent_id }
    ).data
  end

  def get_parent(parent_id, ret = [])
    data = get_dir(parent_id)
    ret.unshift(data.title)
    data.parents.map{|parent|
      get_parent(parent.id, ret)
    }
    ret
  end
end

# begin parse options
opt = OptionParser.new

opt.on('-v', '--verbose') do |v|
  debug = true
end

owner = nil
opt.on('--owner EMAIL') do |email|
  owner = email
end

admin = nil
opt.on('--admin EMAIL') do |email|
  admin = email
end

issuer = nil
opt.on('--issuer EMAIL') do |email|
  issuer = email
end

opt.parse!(ARGV)
# end parse options


def get_owners(owners)
  owners.map{|owner| "#{owner.try(:display_name)} <#{owner.try(:email_address)}>"}
end

def get_permissions(client, drive, file_id)
  permission_result = client.execute(
    :api_method => drive.permissions.list,
    :parameters => { 'fileId' => file_id }
  )
  permission_result.data.items.map{|permission|
    "#{permission.role}/#{permission.type}:#{permission.name} <#{permission.try(:email_address)}>"
  }
end

if issuer.nil?
  raise "Required option: --issuer"
end

owners = []
if owner.nil?
  if admin.nil?
    raise "Required option: --admin or --owner"
  end
  client, drive, directory = setup(issuer, admin)
  owners = get_all_users(client, directory).map{|u| u.primary_email}
elsif
  owners << owner
end

results = []
owners.each do |owner|
  client, drive, directory = setup(issuer, owner)
  dircache = DirectoryCache.new(client, drive)
  all_files_result = get_files(client, drive, owner)
  all_files_result.data.items.each do |file|
    if debug
      STDERR.puts "fetching id: #{file.id}, title: #{file.title}..."
    end

    file.parents.each do |parent|
      results.push({
	:folder_owner => get_owners(dircache.get_dir(parent.id).owners),
	:title => dircache.get_parent(parent.id, []).join('/') + '/' + file.title,
	:permissions => get_permissions(client, drive, file.id).join(',')
      })
    end
  end
end

results.each do |r|
  puts r.values.join("\t")
end
