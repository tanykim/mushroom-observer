# encoding: utf-8
#
#  = Language Localization and Export Files
#
#  Translation strings (also called "localization strings" in places) are
#  exported to two types of files:
#
#  === Localization files
#
#  YAML files: <tt>lang/ui/en-US.yml</tt>  These are written automatically and
#  should never be edited by hand anymore.
#
#  === Export files
#
#  Text files: <tt>lang/ui/en-US.yml</tt>  These are meant to be edited by hand.
#  Note that one of the locales is chosen as the "official" locale.  All the
#  other files are patterned after this one.  You can import changes from any
#  of these files, and it will update the database and YAML files automatically.
#
################################################################################

module LanguageExporter
  # require 'yaml'
  # begin
  #   # This engine does a better job with Greek and Cyrillic characters.
  #   # Yikes!  But it slows down the unit tests by a factor of 10 or more!
  #   YAML::ENGINE.yamler = 'psych'
  # rescue
  # end

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    attr_accessor :verbose, :safe_mode
  end

  def verbose(msg)
    puts msg if Language.verbose
  end

  def safe_mode
    Language.safe_mode
  end

  # This is the file used by Globalite; DO NOT EDIT THIS FILE!
  def localization_file
    "#{RAILS_ROOT}/lang/ui/#{locale}.yml"
  end

  # This is the hand-editable export file.
  def export_file
    "#{RAILS_ROOT}/lang/ui/#{locale}.txt"
  end

  # Update the YAML file used by Globalite.
  def update_localization_file
    old_data = read_localization_file
    new_data = localization_strings
    write_localization_file(old_data.merge(new_data))
  end

  # Update the editable export file.
  def update_export_file
    lines = format_export_file(localization_strings, translated_strings)
    write_export_file_lines(lines)
  end

  # Check syntax of export file.
  def check_export_syntax
    check_export_file_for_duplicates
    check_export_file_for_obvious_errors
    check_export_file_data
  end

  # Import changes from export file.
  def import_from_file
    any_changes = false
    unless old_user = User.current
      raise "Must specify a user to import translation file!" unless official
      User.current = User.admin
    end
    old_data = localization_strings
    new_data = read_export_file
    good_tags = Language.official.read_export_file
    tag_lookup = translation_strings_hash
    for tag, new_val in new_data
      if new_val.is_a?(String) and
         good_tags.has_key?(tag)
        new_val = clean_string(new_val)
        old_val = clean_string(old_data[tag])
        if old_val != new_val
          if str = tag_lookup[tag]
            update_string(str, new_val, old_val)
          else
            create_string(tag, new_val, old_val)
          end
          any_changes = true
        end
      end
    end
    User.current = old_user
    return any_changes
  end

  # Strip tags "unused" translation strings from unofficial locales.  That is, remove
  # any strings from unofficial locales which are not also in the official locale.
  def strip
    any_changes = false
    good_tags = Language.official.read_export_file
    for str in translation_strings.reject {|str| good_tags.has_key?(str.tag)}
      verbose("  deleting :#{str.tag}")
      translation_strings.delete(str) unless safe_mode
      any_changes = true
    end
    return any_changes
  end

  def read_export_file
    YAML::load_file(export_file)
  end

  def read_export_file_lines
    File.open(export_file, 'r').readlines
  end

  # Return Hash mapping tag (String) to value (String), include official string
  # wherever translations are missing.
  def localization_strings
    if official
      merge_localization_strings_into({})
    else
      data = Language.official.localization_strings
      merge_localization_strings_into(data)
    end
  end

  # Return Hash mapping tag (String) to value (String), only include strings
  # which have been translated.
  def translated_strings
    merge_localization_strings_into({})
  end

  # Return Hash mapping tag (String) to TranslationString (ActiveRecord instance).
  def translation_strings_hash
    hash = {}
    for str in translation_strings
      hash[str.tag] = str
    end
    return hash
  end

  # Clean excess whitespace out of a string.
  def clean_string(val)
    val.to_s.gsub(/\\r|\r/, '').
             gsub(/\\n/, "\n").
             gsub(/[ \t]+\n/, "\n").
             gsub(/\n[ \t]+/, "\n").
             sub(/\A\s+/, '').
             sub(/\s+\Z/, '')
  end

################################################################################

private
  def read_localization_file
    YAML::load_file(localization_file)
  end

  def write_localization_file(data)
    File.open(localization_file, 'w') do |fh|
      old_engine = YAML::ENGINE.yamler
      YAML::ENGINE.yamler = 'psych'
      YAML::dump(data, fh)
      YAML::ENGINE.yamler = old_engine
    end
  end

  def write_export_file_lines(output_lines)
    File.open(export_file, 'w') do |fh|
      for line in output_lines
        fh.write(line)
      end
    end
  end

  def merge_localization_strings_into(data)
    for str in translation_strings
      data[str.tag] = str.text
    end
    return data
  end

  def create_string(tag, new_val, old_val)
    verbose("  adding :#{tag}")
    verbose("    was #{old_val.inspect}")
    verbose("    now #{new_val.inspect}")
    unless safe_mode
      translation_strings.create(
        :tag => tag,
        :text => new_val,
        :modified => Time.now,
        :user_id => User.current_id
      )
    end
  end

  def update_string(str, new_val, old_val)
    verbose("  updating :#{str.tag}")
    verbose("    was #{old_val.inspect}")
    verbose("    now #{new_val.inspect}")
    unless safe_mode
      str.update_attributes(
        :text => new_val,
        :modified => Time.now,
        :user_id => User.current_id
      )
    end
  end

  # ----------------------------
  #  :section: Formatting
  # ----------------------------

  # Takes two Hash'es, one mapping tag to translated string, another containing
  # only those tags which have translations.
  def format_export_file(strings, translated)
    template_lines = Language.official.read_export_file_lines
    output_lines = []
    in_tag = false
    for line in template_lines
      if line.match(/^(['"]?(\w+)['"]?:)/)
        out, tag = $1, $2
        out += translated.has_key?(tag) ? ' ' : '  '
        out += format_string(strings[tag])
        output_lines << out
        in_tag = true if line.match(/ >\s*$/)
      elsif in_tag
        in_tag = false unless line.match(/\S/)
      else
        output_lines << line.sub(/\s+$/, "\n")
      end
    end
    return output_lines
  end

  def format_string(val)
    val = clean_string(val)
    if val.match(/\\n|\n/)
      format_multiline_string(val)
    elsif val.match(/:(\s|$)| #/) or
          val.match(/^(no|yes)$/i) or
          (val.match(/^\W/) and val.force_encoding('binary')[0].ord < 128)
      escape_string(val)
    elsif val == ''
      '""'
    else
      val
    end + "\n"
  end

  def format_multiline_string(val)
    val = val.sub(/(\\n|\n)+\Z/, '')
    out = ">\n"
    for line in val.split(/\\n|\n/)
      out += '  ' + line + "\\n\n"
    end
    return out
  end

  def escape_string(val)
    '"' + val.gsub(/([\"\\])/, '\\\\\\1') + '"'
  end

  # ----------------------------
  #  :section: Validation
  # ----------------------------

  def check_export_file_for_duplicates
    once = {}
    twice = {}
    pass = true
    for line in read_export_file_lines
      if line.match(/^['"]?(\w+)['"]?:/)
        if once[$1] and not twice[$1]
          verbose("#{locale} #{$1}: tag appears more than once")
          twice[$1] = true
          pass = false
        end
        once[$1] = true
      end
    end
    return pass
  end

  def check_export_file_data
    pass = true
    data = read_export_file
    for tag, str in data
      if not tag.is_a?(String)
        verbose("#{locale} #{tag}: tag is a #{tag.class.name} instead of a String")
        pass = false
      end
      if not str.is_a?(String)
        verbose("#{locale} #{tag}: value is a #{str.class.name} instead of a String")
        pass = false
      end
      if not validate_square_brackets(str)
        verbose("#{locale} #{tag}: square brackets messed up: #{str.inspect}")
        pass = false
      end
    end
    return pass
  end

  def check_export_file_for_obvious_errors
    @pass = true
    @in_tag = false
    @line_number = 0
    for line in read_export_file_lines
      @line_number += 1
      check_export_line(line)
    end
    return @pass
  end

  def check_export_line(line)
    if line.match(/^(['"]?(\w+)['"]?):/)
      quoted_tag, tag, str = $1, $2, $'
      check_export_tag_def_line(quoted_tag, tag, str)
    elsif @in_tag
      check_export_multi_line(line)
    else
      check_export_other_line(line)
    end
  end

  def check_export_tag_def_line(quoted_tag, tag, str)
    if @in_tag
      verbose("#{locale} #{@line_number}: didn't finish multi-line string for #{@in_tag}")
      @in_tag = false
      @pass = false
    end
    if (quoted_tag.match(/^'/) and not quoted_tag.match(/'$/)) or
       (quoted_tag.match(/^"/) and not quoted_tag.match(/"$/)) or
       (quoted_tag.match(/['"]$/) and not quoted_tag.match(/^['"]/))
      verbose("#{locale} #{@line_number}: invalid tag quotes: #{quoted_tag.inspect}")
      @pass = false
    end
    if quoted_tag.match(/^(yes|no)$/i)
      verbose("#{locale} #{@line_number}: 'yes' and 'no' must be quoted in YAML files")
      @pass = false
    elsif not validate_tag(tag)
      verbose("#{locale} #{@line_number}: invalid tag: #{tag.inspect}")
      @pass = false
    end
    str.strip!
    if str == '>'
      @in_tag = tag
    elsif str == ''
      verbose("#{locale} #{@line_number}: missing string")
      @pass = false
    elsif not validate_string(str)
      verbose("#{locale} #{@line_number}: invalid string: #{str.inspect}")
      @pass = false
    end
  end

  def check_export_multi_line(line)
    if not line.match(/\S/)
      @in_tag = false
    elsif not line.match(/^ /)
      verbose("#{locale} #{@line_number}: failed to indent multi-ine string for #{@in_tag}")
      @pass = false
    end
  end

  def check_export_other_line(line)
    if not line.match(/^#/) and
       not line.match(/^---\s*$/) and
       line.match(/\S/)
      verbose("#{locale} #{@line_number}: invalid syntax between tags: #{line.inspect}")
      @pass = false
    end
  end

  def validate_tag(str)
    str.match(/^\w+$/)
  end

  def validate_string(str)
    str = str.strip_squeeze
    pass = true
    if str.match(/^(yes|no)$/i)
      pass = false
    elsif str.match(/^'/)
      pass = false unless str.match(/^'([^'\\]|\\.)*'$/)
    elsif str.match(/^"/)
      pass = false unless str.match(/^"([^"\\]|\\.)*"$/)
    elsif str.match(/:(\s|$)| #/) or
          (str.match(/^[^\w\(]/) and str.force_encoding('binary')[0].ord < 128)
      pass = false
    end
    return pass
  end

  def validate_square_brackets(value)
    value = value.to_s.dup
    pass = true
    while value.match(/\S/)
      if value.sub!(/^[^\[\]]+/, '')
      elsif value.sub!(/^\[\[/, '')
      elsif value.sub!(/^\]\]/, '')
      elsif value.sub!(/^\[\w+\]/, '')
      elsif value.sub!(/^\[:\w+(?:\(([^\[\]]+)\))?\]/, '')
        if $1 and not validate_square_brackets_args($1)
          pass = false
          break
        end
      else
        pass = false
        break
      end
    end
    return pass
  end

  def validate_square_brackets_args(args)
    pass = true
    for pair in args.split(',')
      if !pair.match(/^ :?\w+ = (
            '.*' | ".*" | -?\d+(\.\d+)? | :\w+ | [a-z][a-z_]*\d*
          )$/x)
        pass = false
        break
      end
    end
    return pass
  end
end
