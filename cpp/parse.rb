require 'rdf'
require 'linkeddata'

DEFAULT_LICENSE = 'http://usefulinc.com/doap/licenses/gpl'

@objRegex = /#X obj \d+ \d+ /
@msgRegex = /#X msg \d+ \d+ /
@controlInRegex = /#{@objRegex}r(?:eceive){0,1}\s*\\\$0-lv2-(.*);\s*/
@controlOutRegex = /#{@objRegex}s(?:end){0,1}\s*\\\$0-lv2-(.*);\s*/
@controlLabelRegex = /label:\s*(\w*)/
@floatRegex = /\d+(?:\.\d+)?/
@rangeRegex = /range:\s+(#{@floatRegex})\s*(#{@floatRegex})\s*(#{@floatRegex})/

def get_control_data(content)
  data = {}
  data[:symbol] = content.match(/\A(\w+)/)[0]
  data[:label] =
    if content =~ @controlLabelRegex
      $1
    end
  data[:range] = 
    if content =~ @rangeRegex
      [$1, $2, $3]
    end
  return data
end

def parse_pd_file(patch_path)
  input = 0
  output = 0
  name = nil
  uri = nil
  in_controls = []
  out_controls = []
  license = DEFAULT_LICENSE

  File.open(patch_path) do |f|
    lines = []
    #unwrap wrapped lines
    f.readlines.each do |l|
      #pd lines start with # unless they're a continuation
      unless l =~ /\A#/ or lines.size == 0
        l = lines.pop + l
      end
      lines << l.chomp
    end

    lines.each do |l|
      if l =~ /#{@objRegex}dac~\s(.*);\s*/
        $1.scan(/\d+/).each do |d|
          output = d.to_i if d.to_i > output
        end
      elsif l =~ /#{@objRegex}adc~\s(.*);\s*/
        $1.scan(/\d+/).each do |d|
          input = d.to_i if d.to_i > input
        end
      elsif l =~ @controlInRegex
        in_controls << get_control_data($1)
      elsif l =~ @controlOutRegex
        out_controls << get_control_data($1)
      elsif l =~ /#{@msgRegex}pluginURI:\s(.*);\s*/
        uri = $1
      elsif l =~ /#{@msgRegex}pluginName:\s(.*);\s*/
        name = $1
      elsif l =~ /#{@msgRegex}pluginLicense:\s(.*);\s*/
        license = $1
      end
    end

    raise "need uri" unless uri
    raise "need name" unless name
    raise "need at least one control or audio input or output" unless input + output + in_controls.size + out_controls.size > 0

    outdata = {
      :name => name,
      :uri => uri,
      :license => license
    }

    outdata[:audio_in] = input
    outdata[:audio_out] = output
    outdata[:control_in] = in_controls if in_controls.size
    outdata[:control_out] = out_controls if out_controls.size
    return outdata
  end
end

def print_control(data)
  r = data[:range]
  puts "\t#{data[:symbol]}"
  puts "\t\tlabel: #{data[:label]}" if data[:label]
  puts "\t\trange: #{r.join(', ')}" if r
end

def print_plugin(data)
  puts "name: #{data[:name]}"
  puts "uri: #{data[:uri]}"
  puts "license: #{data[:license]}"
  puts "audio inputs: #{data[:audio_in]}"
  puts "audio outputs: #{data[:audio_out]}"

  if data[:control_in].size
    puts "control inputs:"
    data[:control_in].each do |c|
      print_control(c)
    end
  end

  if data[:control_out].size
    puts "control outputs:"
    data[:control_out].each do |c|
      print_control(c)
    end
  end
end

plugins = ["patch.pd"]
plugins.each do |p|
  data = parse_pd_file(p)
  print_plugin(data)
end
