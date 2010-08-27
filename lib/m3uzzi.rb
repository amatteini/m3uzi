$:<< File.dirname(__FILE__)
require 'tag'
require 'file'

class M3Uzzi

  # Unsupported: KEY PROGRAM-DATE-TIME STREAM-INF DISCONTINUITY
  VALID_TAGS = %w{TARGETDURATION MEDIA-SEQUENCE ALLOW-CACHE STREAM-INF ENDLIST VERSION}

  attr_accessor :files
  attr_accessor :tags

  def initialize
    @files = []
    @tags = []
  end


  #-------------------------------------
  # Read/Write M3U8 Files
  #-------------------------------------

  def self.read(path)
    m3u = self.new
    lines = ::File.readlines(path)
    lines.each_with_index do |line, i|
      case type(line)
      when :tag
        name, value = parse_general_tag(line)
        m3u.add_tag do |tag|
          tag.name = name
          tag.value = value
        end
      when :info
        duration, description = parse_file_tag(line)
        m3u.add_file do |file|
          file.path = lines[i+1].strip
          file.duration = duration
          file.description = description
        end
      else
        next
      end
    end
    m3u
  end

  def write(path)
    f = ::File.open(path, "w")
    f << "#EXTM3U\n"
    tags.each do |tag|
      next if %w{M3U ENDLIST}.include?(tag.name.to_s.upcase)
      f << "#EXT-X-#{tag.name.to_s.upcase}"
      tag.value && f << ":#{tag.value}"
      f << "\n"
    end
    if !self[:targetduration]
      f << "#EXT-X-TARGETDURATION:#{files.map(&:duration).sum}\n"
    end
    files.each do |file|
      f << "#EXTINF:#{file.duration}"
      file.description && f << ", #{file.description}"
      f << "\n#{file.path}\n"
    end
    f << "#EXT-X-ENDLIST"
    f.close()
  end


  #-------------------------------------
  # Files
  #-------------------------------------

  def add_file(&block)
    new_file = M3Uzzi::File.new
    yield(new_file)
    @files << new_file
  end

  def filenames
    files.map{|file| file.path }
  end


  #-------------------------------------
  # Tags
  #-------------------------------------

  def add_tag(&block)
    new_tag = M3Uzzi::Tag.new
    yield(new_tag)
    @tags << new_tag
  end

  def [](key)
    tag_name = key.to_s.upcase.sub("_", "-")
    obj = tags.detect{|tag| tag.name == tag_name }
    obj && obj.value
  end

  def []=(key, value)
    add_tag do |tag|
      tag.name = key
      tag.value = value
    end
  end


protected

  def self.type(line)
    case line
    when /^\s*$/
      :whitespace
    when /^#(?!EXT)/
      :comment
    when /^#EXTINF/
      :info
    when /^#EXT(?!INF)/
      :tag
    else
      :file
    end
  end

  def self.parse_general_tag(line)
    line.match(/^#EXT(?:-X-)?(?!STREAM-INF)([^:\n]+)(:([^\n]+))?$/).values_at(1, 3)
  end

  def self.parse_file_tag(line)
    line.match(/^#EXTINF:[ \t]*(\d+),?[ \t]*(.*)$/).values_at(1, 2)
  end

  def self.parse_stream_tag(line)
    match = line.match(/^#EXT-X-STREAM-INF:(.*)$/)[1]
    attributes = match.split(/\s*,\s*/)
    attributes.map{|a| a.split(/\s*=\s*/) }
  end

end
