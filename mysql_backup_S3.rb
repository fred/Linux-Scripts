#!/bin/env ruby
#######################################
#### WRITEN by Frederico de Souza #####
#### fred.the.master@gmail.com    #####
#### Free to use as in free beer  #####
#######################################

if RUBY_VERSION.match("^1.8")
  require "rubygems"
  require 'ftools'
  require 'pathname'
end

if RUBY_VERSION.match("^1.9")
  require 'pathname'
  require 'fileutils'
end

require 'aws/s3'
require 'syslog'

#########################
##   SCRIPT SETTINGS   ##
#########################

# Encryption
@rsa_encryption = true
@rsa_password = "very_long_string_to_encrypt_backups"

@unattended_mode = true
@access_key_id = "xxxxxxxxxxxxxxxxxxxx"
@secret_access_key = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
@bucket_name = "mybucket"
@home = "/backup/local"

@time = Time.now
@syslog_tag = "mysql_backup_S3"

# nice value: -19 to 19
# default 0
@nice = 18

# lzma compression rates: 1-2 (fast) 3-9 (slow)
# default 7, 2=10 second, 3=50 seconds
@lzma_compress_rate = 4

@hostname = `hostname`.chomp

# Email Settings
@email_from = "root@#{@hostname}"
@send_to = "root"

# Folder Settings
@data_dir =  "#{@home}/mysql/tmp/#{@time.strftime("%Y")}/#{@time.strftime("%m")}"
@done_data_dir = "#{@home}/mysql/#{@time.strftime("%Y")}/#{@time.strftime("%m")}"
@filename = "#{@time.strftime("%Y%m%d__%H%M%S")}"
@bucket_folder = "#{@time.strftime("%Y")}/#{@time.strftime("%m")}/"

@log_file = "#{@home}/mysql/backup.log"

# set to true if you want to keep backups on the hard drive. 
@keep_backups = true

# Array of databases to backup 
@databases = [
  {:name => "mysql", :dump_options => "", :append_name => ""},
  {:name => "db1", :dump_options => "--single-transaction", :append_name => ""},
  {:name => "db2", :dump_options => "--single-transaction", :append_name => ""},
  {:name => "db3", :dump_options => "", :append_name => ""}
]

# Also make a single backup of all databases. 
# this will be a single SQL file with schema.
# may not work if you have sql views.
@all_databases = true

# Extra options to append to mysqldump
@extra_dump_options = ""

# Username / Password to access DB
# it's good to create a user with READ only access to all databases.
# for example: GRANT SELECT ON *.* TO 'fred'@'localhost' IDENTIFIED by 'fred'
if ENV['DB_USERNAME']
  @db_username = ENV['DB_USERNAME']
else
  @db_username = "root"
end
if ENV['DB_PASSWORD']
  @db_password = ENV['DB_PASSWORD']
else
  @db_password = "mysql-password"
end

# HOST for mysql
@mysql_host = "localhost"

@lines = "\n----------------------------------------------------------"

if @unattended_mode == false
  puts "Welcome!"
  puts "--------"
  puts "Program Variables:"
  puts "------------------" 
  puts "- Server Username:    #{@server_username}"
  puts "- Bucket:             #{@bucket_name}"
  puts "- Local Dump Dir:     #{@data_dir}"
  puts "- Local Time of Dump: #{@time}"
  puts "- Remote Path:        #{@remote_destination}"
  puts "- All Databases?      #{@all_databases}"
  puts "- DB Username:        #{@db_username}"
  puts "- DB Password:        Not Shown"
  puts "- Unattended mode:    #{@unattended_mode}"
  puts @lines
  puts "Is this Information correct? will continue in 5 seconds"
end


def to_syslog(tag,string)
  Syslog.open(tag)
  Syslog.info(string)
  Syslog.close
end


def to_file_size(num)
  case num
  when 0 
    return "0 byte"
  when 1..1024
    return "1K"
  when 1025..1048576
    kb = num/1024.0
    return "#{f_to_dec(kb)} Kb"
  when 1024577..1049165824
    kb = num/1024.0
    mb = kb / 1024.0
    return "#{f_to_dec(mb)} Mb"
  else
    kb = num/1024.0
    mb = kb / 1024.0
    gb = mb / 1024.0
    return "#{f_to_dec(gb)} Gb"
  end
end

def f_to_dec(f, prec=2,sep='.')
  num = f.to_i.to_s
  dig = ((prec-(post=((f*(10**prec)).to_i%(10**prec)).to_s).size).times do post='0'+post end; post)
  return num+sep+dig
end

def check_directories
  begin
    FileUtils.mkdir_p(@data_dir,:mode => 0700)
    FileUtils.mkdir_p(@done_data_dir, :mode => 0700)
  rescue
    puts "Cannot create local directory #{@data_dir}"
    puts "Going to use '/tmp/#{@data_dir}' folder instead."
    @data_dir = "/tmp/#{@data_dir}"
  end
  begin
    FileUtils.mkdir_p(@done_data_dir)
  rescue
    puts "Cannot create local directory #{@done_data_dir}"
    puts "Going to use '/tmp/#{@done_data_dir}' folder instead."
    @data_dir = "/tmp/#{@done_data_dir}"
  end
end

def email_on_error(error_msg)
  @time = Time.now
  @server_name = `hostname`.chomp
  @subject = "ETC backup to S3 failed"
  @body = "\n ETC backup to S3 failed:
  \n Server: #{`uname -ns`}
  \n Time: #{@time.to_s}
  \n Error: #{error_msg}
  "
  command = "echo \"#{@body}\" | sendEmail -f \"#{@email_from}\" -u \"#{@subject}\" -t \"#{@send_to}\" -q"  
end

def check_programs

  if `which lzma`.empty?
    puts "LZMA not found or not installed. Exiting"
    exit
  end

  if no_openssl = `which openssl`.empty?
    puts "OpenSSL not found or not installed. Exiting"
    exit
  end

  if no_mysqldump = `which mysqldump`.empty?
    puts "mysqldump not found or not installed. Exiting"
    exit
  end

end

def check_settings
  if !ENV['DB_USERNAME']
    puts "WARNING: Database Username not set, using 'root'"
  end
  if !ENV['DB_PASSWORD']
    puts "WARNING: Database User Password not set, using '' (blank)"
  end
  if !ENV['AMAZON_ACCESS_KEY_ID']
    puts "FATAL: AMAZON_ACCESS_KEY_ID not set, quiting now."
    exit
  end
  if !ENV['AMAZON_SECRET_ACCESS_KEY']
    puts "FATAL: AMAZON_SECRET_ACCESS_KEY not set, quiting now."
    exit
  end  
end


# Function to make the Database Dumps
def mysqldump(options)
    name = options[:name].to_s
    append_name = options[:append_name].to_s
    dump_options = options[:dump_options].to_s
    if @db_password.to_s.empty?
      db_password = ""
    else
      db_password = "-p#{@db_password}"
    end
    file_name = "#{@data_dir}/#{append_name}#{name}_#{@filename}.sql"
    puts "Dumping #{options[:name]} into #{file_name}\n"
    command = " nice -n #{@nice} mysqldump -h #{@mysql_host} -u #{@db_username} #{db_password} #{dump_options} #{@extra_dump_options} #{name} > #{file_name}"
    puts "EXECUTING:\n  #{command}"
    system(command)
    return file_name
end


def compress_file(file_name)
  puts "Compressing file #{file_name}."
  # command = " nice tar -cjpf #{file_name}.tar.bz2 #{file_name}"
  command = " nice -n #{@nice} lzma -#{@lzma_compress_rate} -z #{file_name}"
  puts "EXECUTING:\n  #{command}"
  if system(command)
    #FileUtils.rm_rf(filename) if File.exists?(filename)
    return file_name+".lzma"
  else
    return nil
  end
end

def encrypt_file(file_name)
  # Openssl encryption using Bluefish-CBC with Salt.
  command = " nice -n #{@nice} openssl enc -bf-cbc -salt -in #{file_name} -out #{file_name}.enc -pass pass:#{@rsa_password}"
  # To decrypt: 
  # openssl enc -d -bf-cbc -in database_20090328__010010.sql.lzma > database_20090328__010010.sql.lzma 
  puts "EXECUTING:\n  #{command}"
  system(command)
  if system(command)
    # If deleted original file 
    FileUtils.rm_rf(file_name)
    return file_name+".enc"
  else
    return nil
  end
end

# Function to run the actual mysqldump command
def make_mysql_backup
  if @all_databases
    options = {
      :name => "",
      :append_name => "all",
      :dump_options => "--all-databases"
    }
    file_name = mysqldump(options)
    new_file_name = compress_file(file_name)
    encrypt_file(new_file_name) if @rsa_encryption
  end
  if @databases && !@databases.empty?
    @databases.each do |db|
      options = {
        :name => db[:name].to_s,
        :dump_options => db[:dump_options].to_s,
        :append_name => db[:append_name].to_s
      }
      file_name = mysqldump(options)
      new_file_name = compress_file(file_name)
      encrypt_file(new_file_name) if @rsa_encryption
    end
  end
end

# Function to stablish connection
def stablish_connection
  begin
    AWS::S3::Base.establish_connection!(
      :access_key_id     => @access_key_id,
      :secret_access_key => @secret_access_key
    )
  rescue => exception
    puts @lines
    puts "There was an error: "
    puts exception.to_s
    exit
  end
  puts "Good, Connection Stablished."
end


def list_buckets
  puts "Current buckets:"
  buckets = AWS::S3::Bucket.list
  if buckets.empty? 
    puts "[]"
  else
    buckets.each do |t|
      puts @lines
      puts "Name: #{t.name}"
      puts "Date: #{t.creation_date}"
      puts @lines
    end
  end
end


# Function to find or create a bucket
def find_bucket(bucket_name)
  if bucket = AWS::S3::Bucket.find(bucket_name)
    puts "Bucket #{bucket_name} found."
    bucket
  else
    puts "The bucket #{bucket_name} could not be found"
    nil
  end
end


# Function to find or create a bucket
def create_bucket(bucket_name)
  begin
    puts 'Creating the bucket now.'
    if AWS::S3::Bucket.create(bucket_name)
      puts "Good, bucket #{bucket_name} created."
    end
  rescue 
    puts "The bucket #{bucket_name} could not be created"
    return
  end
end

# Function to find or create a bucket
def find_or_create_bucket
  begin
    AWS::S3::Bucket.find(@bucket_name)
  rescue
    puts "Bucket #{@bucket_name} not found."
    puts 'Creating the bucket now.'
    AWS::S3::Bucket.create(@bucket_name)
    retry
  end
  puts "Good, bucket #{@bucket_name} found."
end


# Function to send data to bucket
def send_data
  puts "Full Pathname localy is #{@data_dir}."
  @files_count = 0 
  @data_transferred = 0
  
  p = Pathname.new(@data_dir)
  p.children.each do |item|
    file_name = item.relative_path_from(Pathname.new(@data_dir)).to_s
    @files_count += 1
    @data_transferred += item.size
    puts "Putting Local File: '#{item}'"
    puts "To bucket: '#{@bucket_name}/#{file_name}'"
    AWS::S3::S3Object.store("#{@bucket_folder}#{file_name}", open(item), @bucket_name)
    puts @lines
    if @keep_backups
      puts "Keeping backup file #{file_name} in #{@done_data_dir}"
      FileUtils.mv(item, @done_data_dir, :noop => false, :verbose => false)
    else
      puts "Deleting backup file #{file_name}"
      FileUtils.rm_rf(item)
    end
  end

  puts @lines
  msg = "Finished transfer FilesCopied=#{@files_count} Transfered=#{to_file_size(@data_transferred)}"
  puts "#{msg}"
  to_syslog(@syslog_tag,msg)
end


#############
##  START  ##
#############

## Execution Start here ##
def main_program

  check_programs
  check_directories

  ### START MYSQL DUMP ###
  puts @lines
  puts "Starting MYSQL Dump \n"
  sleep 1
  if @all_databases 
    puts "INFO: Going to dump all databases into"
    puts "  '#{@data_dir}'"
  else
    puts "INFO: Going to dump '#{@databases.join(", ")}' databases into"
    puts "  '#{@data_dir}'"
  end
  
  puts @lines
  puts "Starting MYSQL dump..."
  make_mysql_backup
  sleep 2
  
  puts @lines
  puts "Stablishing Connection to S3 account."
  stablish_connection
  
  find_or_create_bucket
  
  puts @lines
  puts "Now Going to copy Data to S3 bucket #{@bucket_name}."
  send_data
  
  puts @lines
  puts "#{@time} -- DONE"
  puts @lines

  file = File.open(@log_file,"a")
  file.puts(Time.now)
  file.close

end

begin
  main_program
rescue => e
  email_on_error(e)
end
