#! /usr/bin/env ruby

require 'csv'
require 'date'
require 'logger'
# require 'nokogiri'
# require 'open-uri'
require 'optparse'
require 'pp'

$options = { :debug => false,
             :pc => false,
             :log_output => STDOUT,
           }
$logger = Logger.new($options[:log_output])
$logger.level = Logger::INFO
$logger.formatter = proc do |severity, datetime, progname, msg|
  "#{msg}\n"
end

OptionParser.new do |opts|
  opts.on("-d", "--debug", "Debug information") do
    $options[:debug] = true
    $logger.level = Logger::DEBUG
  end
  opts.on("-fINPUT","--file=INPUT", "Input file") do |f|
    $options[:input] = f
    $options[:log_output] = 'invitations.log'
  end
  opts.on("-p", "--pc-members", "Dump PC members in HotCRP format") do
    $options[:pc] = true
    $options[:log_output] = STDOUT
  end
  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!


def getEmails(csvfile)
  $logger.debug("reading from #{csvfile}")
  data = CSV.parse(File.read(csvfile), headers: true)
  # pp(data.to_s())
  header = true
  @addresses = {}
  data.each do |row|
    $logger.debug("#{row['First Name']}: #{row['Email']}")
    if row['Email']
      @addresses[row['Email']] = row
    else
      puts "*** empty email for #{row['First Name']}"
    end
  end
  return @addresses
end

def printAddresses(addresses)
  @valid = 0
  @invalid = 0
  addresses.each do |email, data|
    if data
      $logger.debug("#{data['First Name']} #{data['Last Name']}: #{email}")
      @valid += 1
    else
      $logger.error("**** invalid data for #{email}")
      @invalid += 1
    end
  end
  $logger.info("Total #{@valid + @invalid}, valid: #{@valid}")
end

def dumpPC(addresses)
  @valid = 0
  @accepted = 0
  @declined = 0
  @no_answer = 0
  @headers = ['first', 'last', 'email', 'affiliation', 'roles']
  csv = CSV.open('pc_hotcrp.csv', 'wb')
  # , headers: @headers, write_headers: true)
  csv << @headers
  addresses.each do |email, data|
    if data
      $logger.debug("#{data['First Name']} #{data['Last Name']}: #{email}")
      @valid += 1
      if data['Status'] == 'Accepted'
        @accepted += 1
        $logger.info("#{data['First Name']} #{data['Last Name']}: #{email}")
        csv << [data['First Name'], data['Last Name'], data['Email'], data['Affiliation'], 'pc']
      elsif data['Status'] == 'Declined'
        @declined += 1
      else
        @no_answer += 1
      end
    end
  end
  $logger.info("Total: #{@valid}\n\taccepted: #{@accepted}\n\tdeclined: #{@declined}\n\tno answer: #{@no_answer}")
end


def sendMail(addresses)
  @sender = "Calin Cascaval <cascaval+pact23@google.com>"

  @invitation = <<-BODY
As the Program Chair for PACT 2023 (https://pact2023.github.io) I would like to invite you to serve in the Program Committee for the 32nd International Conference on Parallel Architectures and Compilation Techniques conference. The conference will take place in Vienna, Austria in Oct 2023. The General Chair is Andreas Krall.  Your expertise would be invaluable for selecting a strong and exciting technical program.

Logistics

Papers will be reviewed by a single committee. We will have two rounds of reviews, with an estimated load of 6-7 papers in the first round and 2-3 papers in the second round. I expect most of the discussions and decisions to happen online via the HotCRP conference management system. The PC meeting will be virtual and we will focus our discussions on the papers with a significant divergence of opinions.

I hope you will accept! Please accept only if you can commit to fulfill all the duties of a PC member, including the following:
  - Personally read and write reviews for all of your assigned papers. I am inviting YOU, not your students or collaborators! If you want to invite someone for a supplementary review, let me know and I will invite them as a bona-fide reviewer through the conference system. This indirection is important to manage conflicts and for the reviewers to receive credit for their effort.
  - Turn your assigned reviews in ON TIME.
  - Write positive and constructive reviews with sufficient detail to help the authors revise their papers and make them better.
  - Keep papers confidential, as required for double-blind reviewing and the integrity of the review process.
  - Actively participate in all on-line discussions of the papers.
  - Abide by the ACM and IEEE Codes of Ethics and Professional Conduct (https://ethics.acm.org/code-of-ethics)
  - Be available during the virtual PC meeting in case we need to consult with you about your reviews.
  - Actively participate in the Best Paper selection, both by nominating papers and discussing and voting for the finalists.

Key dates

  - Abstract submission:         Mar 25, 2023
  - Paper submission:            Apr 1, 2023
  - Review assignment:           Apr 14, 2023
  - First round of reviews due:  May 26, 2023
  - Rebuttal period:             Jun 6-9, 2023
  - Second round of reviews due: Jul 1, 2023
  - Rebuttal period:             Jul 5-7, 2023
  - PC meeting:                  Jul 21, 2023
  - Author notification:         Aug 1, 2023
  - Camera ready:                Sep 1, 2023

Please let me know of your (hopefully positive) decision no later than Feb 8, 2023.

Finally, please let me know if you have any questions. I am looking forward to working with you to put together an exciting program for PACT 2023.

Thank you for your consideration,
Calin

BODY

  addresses.each do |email, data|
    @name = data['First Name']
    f = File.open('mail.txt', 'w')
    f.write("From: #{@sender}\n")
    f.write("To: #{email}\n")
    f.write("Reply-To: #{@sender}\n")
    f.write("Subject: PACT 2023 Program Committee invitation\n")
    f.write("\nDear #{@name},\n\n")
    f.write("#{@invitation}\n")
    f.close
    unless $options[:debug]
      puts `cat mail.txt | /usr/bin/sendgmr -parse_headers`
    else
      $logger.info("sending mail to #{@name}")
    end
  end
end


def main()
  @addresses = getEmails($options[:input])
  if $options[:pc]
    dumpPC(@addresses)
    return
  end
  if $options[:debug]
    printAddresses(@addresses)
  end
  sendMail(@addresses)
end

main()
