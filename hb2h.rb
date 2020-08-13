#!ruby

#Author: insane
#Web: https://www.serendipity.page/
#Desc:
#はてなブログからエクスポートしたMTフォーマットのテキストデータを
#静的Webサイト生成ツールHugoのデータに変換するプログラム
#Usage: ruby hb2h.rb {エクスポートしたテキストファイルのパス}

require "time"
require "fileutils"
require "cgi/util"

OutputDirName = "./entry" #データを出力するディレクトリ名
OutputYAMLExtention = "html" #出力するYAMLファイルの拡張子
HATENATimeFormat = "%m/%d/%Y %H:%M:%S" #エクスポートしたファイル上での日時形式
HugoTimeFormat = "%Y-%m-%dT%H:%M:%S+09:00" #YAML出力する時の日時形式2020-06-28T17:03:00+09:00
RedirectFlag = true #新URLにリダイレクトさせるか。trueの場合、フロントマターにエイリアスを追加
ImgLazyLoadFlag = true #Bodyに含まれる<img>をlazy-loadを追加するか
LB = $/ #改行文字

#１つ１つのデータを表す
class Field
  attr_reader :field_name, :data

  def self.generate(entry, field_name, output_field_name, data)
    self.new(entry, field_name, output_field_name, data)
  end
  
  def initialize(entry, field_name, output_field_name, data)
    @entry = entry
    @field_name = field_name
    @output_field_name = output_field_name
    @data = data
  end

  def to_yaml_line(data)
    "%s: %s"%[@output_field_name, data]
  end

  def to_s
    to_yaml_line(@data)
  end
end

class StrFld < Field
end

class QuotedStrFld < StrFld
  #引用符付きにする
  def quote(str)
    ?' + str.gsub(?',"''") + ?'
  end

  def to_s
    to_yaml_line(quote(@data))
  end
end

# need to unescape
class TitleFld < QuotedStrFld
  def to_s
    str = CGI.unescape_html(@data)
    to_yaml_line(quote(str))
  end
end

class ExcerptFld < QuotedStrFld
  def to_s
    to_yaml_line(quote(@data.split(LB).join))
  end
end

class StatusFld < StrFld
  def to_s
    output = @data == "Publish" ? "false" : "true"
    to_yaml_line(output)
  end
end

class MulStrFld < Field
  def self.generate(entry, field_name, output_field_name, data)
    ret = entry.data[field_name.to_sym]
    if ret
      ret.add(data)
    else
      ret = self.new(entry, field_name, output_field_name, Array.new)
      ret.add(data)
    end
    ret
  end

  def add(data)
    @data << data
  end

  def to_s
    lines = Array.new
    lines << "%s:" % [@output_field_name]
    @data.each{|d|
      lines << ("- " + d)
    }
    lines.join(LB)
  end
end

class BodyFld < Field
  def to_s
    if ImgLazyLoadFlag #独自処理
      @data.gsub('<img ', '<img loading="lazy" ') 
    else
      @data
    end
  end
end

class ExtendedBodyFld < BodyFld
end

#e.g. 01/04/2015 23:31:02
class DateFld < Field
  def initialize(entry, field_name, output_field_name, data)
    super
    @date = DateTime.strptime(data, HATENATimeFormat)
  end

  def to_s
    to_yaml_line(@date.strftime(HugoTimeFormat))
  end
end

#一つの記事
class Entry
  attr_reader :data

  @@unused_fields = Hash.new(0) #使われないフィールド確認用
  def self.unused_fields
    @@unused_fields
  end

  def initialize
    @data = Hash.new
  end

  def add_entry(field_name, data)
    if Mappings[field_name]
      begin
        @data[field_name.to_sym] = Mappings[field_name].first.generate(self,
          field_name, Mappings[field_name].last, data)
      rescue => err
        p field_name
        p data
        p Mappings[field_name].first
        puts err
        exit
      end
    else
      @@unused_fields[field_name.to_sym] += 1
    end
  end

  #YAML形式としてしてパスに保存
  def save_as_YAML(dir, file_name)
    legit_dir = OutputDirName + dir
    #ディレクトリが存在しないなら作成
    FileUtils.mkdir_p(legit_dir) unless Dir.exist?(legit_dir)
    #記事本文を作成。はてなブログでは、<!--more-->が使われていると分割される仕様
    body = @data["BODY".to_sym].to_s
    if @data["EXTENDED BODY".to_sym]
      body << @data["EXTENDED BODY".to_sym].to_s
    end

    File.open(legit_dir + ?/ + file_name, "w"){|f|
      #front matter
      f.puts("---")
      @data.each{|key, value|
        f.puts(value) if Mappings[value.field_name][1]
      }
      f.puts("---")
      #body
      f.puts(body)
    }
  end
end

#はてなブログからエクスポートしたデータと出力フィールドとの対応表（自分の例）
#Hugoテーマ内で独自追加されているfront matterに項目を追加したいなど
#特殊な処理が必要な場合は継承してクラスを作成し、以下に項目を追加
#output_field_nameが存在しないフィールドは自動で追加されない（自分で特殊処理を書く）
#はてなブログのコメントは継承せず（Hugo内部に存在しない機能なので）
Mappings = {
  #field   => [corresponding_class_name, (output_field_name)]
  #Hugo標準のFront Matter
  "AUTHOR" => [StrFld, "author"],
  "TITLE" => [TitleFld, "title"],
  "BASENAME" => [StrFld],
  "STATUS" => [StatusFld, "draft"],
  "DATE" => [DateFld, "date"],
  "CATEGORY" => [MulStrFld, "tags"],
  "BODY" => [BodyFld],
  "EXTENDED BODY" => [ExtendedBodyFld],
  "EXCERPT" => [ExcerptFld, "summary"],
  #Hugo移行に際しURLを変える場合にエイリアス追加（リダイレクト機能）
  "aliases" => [MulStrFld, "aliases"],
  #Hugo非標準（テーマ依存）のFront Matter
  "IMAGE" => [StrFld, "thumbnailImage"],
  "categories" => [MulStrFld, "categories"]
}

def separator(n)
  (?-*n) + LB
end

EntrySeparator = separator(7)
SectionSeparator = separator(5)

# main
unless ARGV[0]
  puts "usage: ruby #$0 {はてなブログからエクスポートしたテキストファイルパス}"
  exit
end

exported_text = ""
begin
  exported_text = File.read(ARGV[0])
rescue => err
  puts err
  exit
end

#出力先フォルダの存在チェック。上書きはしない。存在したらプログラムは終了
if Dir.exist?(OutputDirName)
  puts "フォルダ%sが既に存在します" % [OutputDirName]
  puts "プログラムを終了します"
  exit
end

exported_text.split(EntrySeparator).each{|entry_text|
  entry = Entry.new
  sections = entry_text.split(SectionSeparator)
  section = sections.shift
  section.each_line{|line|
    sep_index = line.index(": ")
    field_name = data = ""
    if sep_index
      field_name = line[0...sep_index]
      data = line.chomp[sep_index + 2..-1]
    else
      field_name = line.chomp
    end
    entry.add_entry(field_name, data)
  }
  sections.each{|multi_line_section|
    sep_index = multi_line_section.index(?: + LB)
    next unless sep_index
    field_name = multi_line_section[0...sep_index]
    data = multi_line_section[sep_index + 2..-1]
    data ||= ""
    entry.add_entry(field_name, data)
  }

  #独自処理
  #カテゴリーの強制追加
  cat = "英語"
  if entry.data[:CATEGORY] &&
      entry.data[:CATEGORY].data.index("Site Operation")
    cat = "サイト運営"
  end
  entry.add_entry("categories", cat)

  #Dramaタグの消去
  if entry.data[:CATEGORY]
    tag_ary = entry.data[:CATEGORY].data
    entry.data[:CATEGORY].data.delete("Drama") if tag_ary.size > 1
    entry.data[:CATEGORY].data.delete("drama") if tag_ary.size > 1
  end

  #ファイル出力先処理
  #e.g. 2018/04/23/230615
  basename = entry.data[:BASENAME].data
  entry.add_entry("aliases", "/entry/" + basename) if RedirectFlag
  rind = basename.rindex(?/)
  dir = ""
  file_name = basename.gsub(?/, ?-)
  if !RedirectFlag && rind
    dir = ?/ + basename[0...rind]
    file_name = basename[rind + 1 .. -1]
  end
  file_name += ?. + OutputYAMLExtention
  entry.save_as_YAML(dir, file_name)
}
