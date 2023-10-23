#! /usr/bin/env ruby

require 'csv'
require 'date'
require 'logger'
# require 'nokogiri'
# require 'open-uri'
require 'optparse'
require 'pp'

$defaults = {
  :hotcrp_assignments => 'hotcrp_assignments.csv',
  :hotcrp_bids => 'pact23-allprefs.csv',
  :hotcrp_conflicts => 'pact23-pcconflicts.csv',
  :hotcrp_reviewers => 'pact23-pc.csv',
  :hotcrp_topics => 'pact32-topics.csv',
  :tpms_assignments => 'pact23_assignments.csv',
  :tpms_bids => 'tpms_bids.csv',
  :tpms_conflicts => 'tpms_conflicts.csv',
  :tpms_reviewers => 'tpms_reviewers.csv',
  :tpms_stats => 'pact23_assignments_rev_stats.txt',
}

$options = {
  :debug => false,
  :assign => false,
  :bids => false,
  :conflicts => false,
  :input => $defaults[:hotcrp_reviewers],
  :log_output => STDOUT,
  :papers => false,
  :pc => false,
}

$logger = Logger.new($options[:log_output])
$logger.level = Logger::INFO
$logger.formatter = proc do |severity, datetime, progname, msg|
  "#{msg}\n"
end

OptionParser.new do |opts|
  opts.on("-a", "--assign", "Convert assignments from TPMS to HotCRP") do
    # TODO: handle rounds
    $options[:assign] = true
  end
  opts.on("-b", "--bids", "Dump bids in TPMS format") do
    $options[:bids] = true
  end
  opts.on("-c", "--conflicts", "Dump conflicts in TPMS format") do
    $options[:conflicts] = true
  end
  opts.on("-d", "--debug", "Debug information") do
    $options[:debug] = true
    $logger.level = Logger::DEBUG
  end
  opts.on("-fINPUT","--file=INPUT", "Input file") do |f|
    $options[:input] = f
    $options[:log_output] = 'invitations.log'
  end
  opts.on("-p", "--package-papers", "Rename and package the papers") do
    $options[:papers] = true
  end
  opts.on("-r", "--reviewers", "Dump PC members in TPMS format") do
    $options[:pc] = true
  end
  opts.on("--all", "Generate all TPMS files") do
    $options[:bids] = true
    $options[:conflicts] = true
    $options[:papers] = true
    $options[:pc] = true
  end
  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

$headers = {
  :first_name => 'first',
  :last_name => 'last',
  :email => 'email',
  :affiliation => 'affiliation',
  :role => 'roles'
}

def getEmails(csvfile)
  $logger.info("PC members: reading from #{csvfile}")
  data = CSV.parse(File.read(csvfile), headers: true)
  # pp(data.to_s())
  header = true
  @addresses = {}
  data.each do |row|
    $logger.debug("#{row[$headers[:first_name]]}: #{row[$headers[:email]]}")
    if row['email']
      @addresses[row[$headers[:email]]] = row
    else
      puts "*** empty email for #{row[$headers[:first_name]]}"
    end
  end
  return @addresses
end

def printAddresses(addresses)
  @valid = 0
  @invalid = 0
  addresses.each do |email, data|
    if data
      $logger.debug("#{data[$headers[:first_name]]} #{data[$headers[:last_name]]}: #{email}")
      @valid += 1
    else
      $logger.error("**** invalid data for #{email}")
      @invalid += 1
    end
  end
  $logger.info("Total #{@valid + @invalid}, valid: #{@valid}")
end

def dumpPC(addresses)
  $logger.info("Reviewers: reading from #{$options[:input]}")
  @valid = 0
  @accepted = 0
  @declined = 0
  @no_answer = 0
  @tpms_header = ['Email', 'FirstName', 'LastName']
  csv = CSV.open($defaults[:tpms_reviewers], 'wb')
  # , headers: @headers, write_headers: true)
  csv << @tpms_header
  addresses.each do |email, data|
    $logger.debug("#{data[$headers[:first_name]]} #{data[$headers[:last_name]]}: #{email}")
    csv << [data[$headers[:email]], data[$headers[:first_name]], data[$headers[:last_name]]]          end
  csv.close()
end

def dumpConflicts()
  csvfile = $defaults[:hotcrp_conflicts]
  $logger.info("Conflicts: reading from #{csvfile}")
  data = CSV.parse(File.read(csvfile), headers: true)
  csv = CSV.open($defaults[:tpms_conflicts], 'wb')
  @tpms_header = [ 'paperID', 'reviewerEmail']
  csv << @tpms_header
  data.each do |row|
    # not a reviewer
    if row['email'] == 'cascaval@acm.org'
      next
    end
    csv << [row['paper'], row['email']]
  end
  csv.close()
end

def dumpBids()
  csvfile = $defaults[:hotcrp_bids]
  $logger.info("Bids: reading from #{csvfile}")
  data = CSV.parse(File.read(csvfile), headers: true)
  @tpms_header = [ 'paperID', 'email', 'score', 'topic_score']
  csv = CSV.open($defaults[:tpms_bids], 'wb')
  csv << @tpms_header
  data.each do |row|
    if row['preference'] or row['topic_score']
      csv << [row['paper'], row['email'], row['preference'], row['topic_score']]
    else
      puts "skipping bid: #{row}" if not row['conflict']
    end
  end
  csv.close()
end

def packagePapers(force)
  if not force
    $logger.info("download papers from http://home.cascaval.us/pact23-papers.tar.bz2")
    return
  end
  $logger.info("Packaging papers")
  @dir = "papers/pact23-papers"

  # remove if exists and mkdir if it doesn't.
  @output_dir = "/tmp/pact23-papers"
  puts `rm -rf #{@output_dir}` if Dir.exists?("#{@output_dir}")
  puts `mkdir -p #{@output_dir}`

  Dir["#{@dir}/*.pdf"].each do |paper|
    name = paper.split('/').last
    new_name = name.sub!('pact23-', '')
    puts `cp #{paper} #{@output_dir}/#{new_name}`
  end
  puts `tar jcvf /tmp/pact23-papers.tar.bz2 --strip-components 2 #{@output_dir}`
  puts `scp /tmp/pact23-papers.tar.bz2 saga.local:/var/www/html/`
end

def assignPapers(round)
  csvfile = $defaults[:tpms_assignments]
  $logger.info("reading assignments from #{csvfile}")
  data = CSV.parse(File.read(csvfile), headers: true)
  @hotcrp_header = ['paper', 'action', 'email', 'reviewtype', 'round']
  csv = CSV.open($defaults[:hotcrp_assignments], 'wb')
  csv << @hotcrp_header
  data.each do |row|
    csv << [row['paper ID'], 'review', row[' reviewer Email'], 'primary', round]
  end
  csv.close()
end

def main()
  if $options[:pc]
    @addresses = getEmails($options[:input])
    dumpPC(@addresses)
    printAddresses(@addresses) if $options[:debug]
  end

  dumpBids() if $options[:bids]
  dumpConflicts() if $options[:conflicts]
  packagePapers(false) if $options[:papers]
  assignPapers('R1') if $options[:assign]
end

main()
