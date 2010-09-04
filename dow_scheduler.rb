#!/usr/bin/env ruby

require 'optparse'
require 'optparse/time'
require 'optparse/uri'
require 'open-uri'
require 'yaml'
# for convert Date, DateTime to Time (Time#parse)
require 'time'

require 'rubygems'
require 'icalendar'

options = {
  :uri => "cals.ics"
}

class DowScheduler
  @@wday_names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
  @@one_day = 86400
  class << self
    def command
      "dow_adjuster"
    end

    def wday_names_hash
      hash = {}
      @@wday_names.each_with_index do |wday_name, i|
        hash[wday_name] = i + 1
      end
      hash
    end
  end


  attr_reader :options, :uri, :cal_file, :cals

  def initialize(argv, options = {})
    @argv = argv

    # Default options values
    @options = options

    parse!

    # read iCal
    if @options[:force]
      load_ical
    else
      begin
        # load cache
        @cals = YAML.load_file("cals.yml")
      rescue
        load_ical
      end
    end
  end

  def load_ical
    @uri = @options[:uri]
    @cal_file = open(@options[:uri])
    @cals = Icalendar.parse(@cal_file)
    File.open("cals.yml", "wb") do |f|
      YAML.dump(@cals, f)
    end
  end

  def parser
    @parser ||= OptionParser.new do |opts|
      opts.banner = "Usage: #{} [options]"
      opts.separator ""
      opts.separator "DRb::Runner options:"
      opts.on("-u", "--uri=uri", String, "Use specified iCal file by uri.") { |v| @options[:uri] = v }
      opts.on("-s", "--start=date", Time, "Start date of the adjusting period, e.g. 2010-01-01.") { |v|  @options[:start_date] = v }
      opts.on("-e", "--end=date", Time, "End date of the adjusting period, e.g. 2010-01-01.") { |v| @options[:end_date] = v }
      opts.on("-d", "--day-of-week=name", DowScheduler.wday_names_hash, "Specifies day of the week name (Mon/Tue/Wed/Thu/Fri/Sat/Sun).") { |v| @options[:day_of_week] = v }
      opts.on("-f", "--force", "Force to reload ical file.") { |v| @options[:force] = true }
      opts.separator ""

      opts.on("-h", "--help", "Show this help message.") { puts opts; exit }
    end
  end

  def parse!
    parser.parse! @argv
    @operation = @argv.shift
    @arguments = @argv
  end

  def wdays
    return @wdays if !@wdays.nil?
    @wdays = Array.new(7, nil)
    @wdays = @wdays.map {|wday| []}
    @cals.first.events.each do |event|
      start_date = event.dtstart
      end_date = event.dtend
      start_date = Time.parse(start_date.to_s) if start_date.class == Date || start_date.class == DateTime
      end_date = Time.parse(end_date.to_s) - @@one_day if end_date.class == Date || end_date.class == DateTime
      next if !@options[:start_date].nil? && @options[:start_date] > start_date
      next if !@options[:end_date].nil? && @options[:end_date] < end_date
      (start_date.wday..end_date.wday).each_with_index do |wday, i|
        @wdays[wday - 1] << [event, start_date + @@one_day * i]
      end
    end
    @wdays
  end
  
  def print_wdays_count
    puts wdays.map {|w| w.size}.inspect
  end

  def print_wdays
    if @options[:day_of_week].nil?
      wdays.each_with_index do |wday, i|
        puts "#{@@wday_names[i]}:"
        print_events(wday)
      end
    else
      print_events(wdays[@options[:day_of_week] - 1])
    end
  end

  protected
  def print_events(events)
    events.each do |event|
      puts "  #{event[1]}: #{event[0].summary}"
    end
  end
end

dow_adjuster = DowScheduler.new(ARGV)
#puts dow_adjuster.options.inspect
dow_adjuster.print_wdays_count
dow_adjuster.print_wdays
