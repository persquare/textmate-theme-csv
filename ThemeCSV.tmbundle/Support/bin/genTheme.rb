#!/usr/bin/env ruby

# genTheme.rb
# Hilton Lipschitz (http://www.hiltmon.com)
# Use and modify freely, attribution appreciated
# 
# This script takes a CSV-like file containing a set of attributes
# and generates a TextMate 2 Theme (and Bundle if necessary).
#
# Use the -b option to write the theme, otherwise the script
# just generates a local .plist version for you to look at.
#
# Note that this version of the script uses the Avian folder
# for TextMate 2 for themes as this is where the current version's
# user bundles are saved.
# 
# Requirements:
# Plist ruby gem
#
# Example usage:
# To just make the .plist: genTheme.rb HiltonsTheme
# To make up update the bundle: genTheme.rb -b HiltonsTheme 

# require 'rubygems'
require 'optparse'
require 'fileutils'
# require "#{ENV['TM_BUNDLE_SUPPORT']}/lib/plist"
require "#{ENV['TM_BUNDLE_SUPPORT']}/lib/plist/generator"
require "#{ENV['TM_BUNDLE_SUPPORT']}/lib/plist/parser"

class GenTheme
  
  VERSION = '0.0.1'
  AUTHOR = 'Hilton Lipschitz'
  TWITTER = '@hiltmon'
  HOME_URL = 'http://www.hiltmon.com'
  LEDE = 'Generate a TextMate 2 Theme from a fixed CSV'
  
  attr_reader :options
  attr_reader :input_file
  
  def initialize(arguments)
    @arguments = arguments
    
    parse_options
    parse_parameters
  end
  
  def run
    # Read the file
    lines = IO.read(@input_file)

    settings = []
    plist = nil
    globals = nil
    gutter = nil
    
    lines.split("\n").each do |line|
      next if line[0] =~ /\/\//
      tokens = line.split(',')
      plist = process_header(tokens) if tokens[0].strip == 'Header'
      globals = process_main(tokens) if tokens[0].strip == 'Main'
      gutter = process_gutter(tokens) if tokens[0].strip == 'Gutter'
      settings << process_scope(tokens) if tokens[0].strip == 'Scope'
    end

    # Build it
    settings.insert(0, globals)
    plist[:settings] = settings
    plist[:gutterSettings] = gutter

    if @options[:build]
      bundle_path = "#{@avian_bundles}/#{plist[:name]}.tmbundle"
      if ! File.directory?(bundle_path)
        puts "Creating #{bundle_path}..."
        Dir.mkdir(bundle_path)
        info = {
          :contactName => plist[:author],
          :description => "A brilliant theme by #{plist[:author]} called #{plist[:name]}.",
          :name => "#{plist[:name]} Bundle",
          :uuid => `uuidgen`.strip
        }
        File.open("#{bundle_path}/info.plist", "w") do |f| 
          f << info.to_plist.sub('Apple Computer', 'Apple')
        end
        # IO.write("#{bundle_path}/info.plist", info.to_plist)
        Dir.mkdir("#{bundle_path}/Themes")
        puts "Created Bundle #{plist[:name]}.tmbundle"
      end
      File.open("#{bundle_path}/Themes/#{plist[:name]}.tmTheme", "w") do |f| 
        f << plist.to_plist.sub('Apple Computer', 'Apple')
      end
      # IO.write("#{bundle_path}/Themes/#{plist[:name]}.tmTheme", plist.to_plist.sub('Apple Computer', 'Apple'))
      puts "Updated embedded theme #{plist[:name]}.tmTheme"
      FileUtils.touch(bundle_path)
    else
      # Write a test plist
      File.open(input_file.sub('.tmcsv', '.plist'), "w") do |f| 
        f << plist.to_plist.sub('Apple Computer', 'Apple')
      end
      # IO.write(input_file.sub('.tmcsv', '.plist'), plist.to_plist.sub('Apple Computer', 'Apple'))
      puts "Wrote #{input_file.sub('.tmcsv', '.plist')}"
    end
    
  end
  
  protected
  
  def process_header(line)
    # author, name, semanticClass, uuid
    raise "Header needs at least 'author, name, semanticClass'." if line.length < 4
    uuid = (line[4].nil? ? `uuidgen` : line[4] )
    {
      :author => line[1].strip,
      :name => line[2].strip,
      :semanticClass => line[3].strip,
      :settings => [],
      :uuid => uuid.strip
    }
  end

  def process_main(line)
    # background, foreground, caret, selection, invisibles, lineHighlight
    raise "Main must contain 'background, foreground, caret, selection, invisibles, lineHighlight'." if line.length != 7
    settings = {
      :background => line[1].strip,
      :foreground => line[2].strip,
      :caret => line[3].strip,
      :selection => line[4].strip, 
      :invisibles => line[5].strip,
      :lineHighlight => line[6].strip
    }
    {
      :settings => settings
    }
  end

  def process_gutter(line)
    # background, foreground, divider, selectionBackground, selectionForeground
    raise "Gutter must contain 'background, foreground, divider, selectionBackground, selectionForeground." if line.length != 6
    settings = {
      :background => line[1].strip,
      :foreground => line[2].strip,
      :divider => line[3].strip,
      :selectionBackground => line[4].strip, 
      :selectionForeground => line[5].strip
    }
  end

  def process_scope(line)
    # name, background, foreground, fontStyle (bold, italic, underline), scopes (comma separated)
    raise "Scope must contain 'name, background, foreground, fontStyle, scopes'." if line.length < 6
    scope = line.slice(5, line.length).join(',').strip
    settings = {}
    settings[:background] = line[2].strip if line[2].strip != 'nil' && line[2].strip != ''
    settings[:foreground] = line[3].strip if line[3].strip != 'nil' && line[3].strip != ''
    settings[:fontStyle] = line[4].strip if line[4].strip != 'nil' && line[4].strip != ''
    {
      :name => line[1].strip,
      :scope => scope,
      :settings => settings
    }
  end
  
  def parse_options
    @options = {}
    
    title = "#{LEDE}\nBy #{AUTHOR} (#{TWITTER}) #{HOME_URL}\n"
    
    @opts = OptionParser.new
    @opts.banner = "#{title}\nUsage: genTheme.rb [options] file.csv"
    @opts.on("-b", "--[no-]build", "Build an Avian Theme") { |b| options[:build] = b }
    @opts.on( '-h', '--help', 'Display this screen' ) { puts @opts; exit 0 }
    begin
      @opts.parse!(@arguments) 
    rescue => e
      puts e
      puts
      puts @opts
      exit (-1)
    end
  end
  
  def parse_parameters
    if @arguments.empty?
      puts @opts
      exit (-1)
    end

    @input_file = ARGV[0]
    @input_file = "#{@input_file}.tmcsv" if @input_file !~ /\.tmcsv$/
    unless File.exists?(@input_file)
      puts "#{@input_file} Not found"
      exit (-1)
    end
    
    # Set paths
    @app_support = "#{ENV['HOME']}/Library/Application\ Support"
    @avian_bundles = "#{@app_support}/TextMate/Bundles"
  end
    
end

app = GenTheme.new(ARGV)
app.run
