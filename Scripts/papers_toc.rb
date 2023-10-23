#! /usr/bin/env ruby

require 'nokogiri'
require 'optparse'
require 'pathname'

$options = {
  :force => false,
}

OptionParser.new do |opts|
  opts.on("-s", "--source-directory DIR",
          "where are the original photos, typically the Selects directory") do |d|
    $options[:source_dir] = Pathname.new(d)
  end
  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

class Author
  attr_reader :first_name, :last_name, :affiliation, :email, :paper

  def initialize(first_name:, last_name:, email:, affiliation:, paper: "")
    @first_name = first_name
    @last_name = last_name
    @email = email
    @affiliation = affiliation
    @paper = paper
  end

  def to_s
    return "#{@first_name} #{@last_name}, _#{@affiliation}_"
  end

  def a_index
    return "#{@first_name} #{@last_name}, #{@email}, #{@paper}"
  end

  def <=> (other)
    @last_name <=> other.last_name
  end
end

class Article
  attr_reader :title, :id
  attr_writer :authors

  def initialize(title, id:)
    @title = title
    @id = id
    @authors = []
  end

  def to_s
    return "**#{@title}**, " + @authors.join(", ")
  end

  def <=>(other)
    @title <=> other.title
  end

end

def list_of_papers(filename)
  @doc = Nokogiri::XML(File.open(filename))
  papers = []
  @doc.css("paper").map { |p|
    title = p.at_css("paper_title").content
    id = p.at_css("event_tracking_number")
    paper = Article.new(title)
    authors = []
    p.css("authors author").map { |a|
      first_name = a.at_css("first_name").content
      last_name = a.at_css("last_name").content
      email = a.at_css("email_address").content
      inst = a.at_css("affiliations affiliation institution").content
      author = Author.new(first_name: first_name, last_name: last_name, email: email, affiliation: inst)
      authors << author
    }
    paper.authors=(authors)
    papers << paper
  }

  i = 1
  papers.sort.each do |p|
    puts "#{i}. #{p}\n\n"
    i += 1
  end
end

def list_of_authors(filename)
  @doc = Nokogiri::XML(File.open(filename))
  authors = []
  @doc.css("paper").map { |p|
    title = p.at_css("paper_title").content
    paper = Article.new(title)
    p.css("authors author").map { |a|
      first_name = a.at_css("first_name").content
      last_name = a.at_css("last_name").content
      email = a.at_css("email_address").content
      inst = a.at_css("affiliations affiliation institution").content
      author = Author.new(first_name: first_name, last_name: last_name, email: email, affiliation: inst, paper: paper.title)
      authors << author
    }
  }

  authors.sort.each do |a|
    puts "#{a.a_index}\n\n"
  end
end

puts "# Accepted papers\n\n"
list_of_papers('pact23-acmcms-toc.xml')
puts "# Accepted posters\n\n"
list_of_papers('pact23-posters-toc.xml')
puts "# Author Index\n\n"
list_of_authors('pact23-acmcms-toc.xml')
