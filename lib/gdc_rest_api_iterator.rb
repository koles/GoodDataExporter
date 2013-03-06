require 'gooddata'
require 'gooddata/model'
require 'gooddata/client'
require 'json'
require 'logger'


class GdcRestApiIterator

  def initialize()
      @accepted_categories = ['projectDashboard','report','reportDefinition','metric', 'prompt']
      @processed_identifiers = []
      @content_by_identifier = {}
      @identifier_to_uri = {}
      @uri_to_identifier = {}
      @saved_identifiers = []
      @element_uris = []
      @primary_labels = {}
  end

  protected

  def cache_identifier_uri(identifier, uri)
    @identifier_to_uri[identifier] = uri
    @uri_to_identifier[uri] = identifier
  end

  def uri(identifier)
    u = @identifier_to_uri[identifier]
    if(u.nil?)
      attr = GoodData::MdObject[identifier]
      cache_identifier_uri(identifier, attr.uri)
      return attr.uri
    else
      return u
    end
  end

  def identifier(uri)
    i=@uri_to_identifier[uri]
    if(i.nil?)
      att = GoodData::MdObject[uri]
      cache_identifier_uri(att.identifier, uri)
      return att.identifier
    else
      return i
    end
  end

  def content(identifier)
    if @content_by_identifier.keys.any? {|k| k.include? identifier}
      return @content_by_identifier[identifier]
    else
      md_obj = GoodData::MdObject[identifier]
      cache_identifier_uri(md_obj.identifier, md_obj.uri)
      category = md_obj.meta['category']
      obj = {category=>{'meta'=>md_obj.meta, 'content'=>md_obj.content}}
      @content_by_identifier[identifier] = obj
      return obj
    end
  end

  def save_md_object_to_file(identifier, content, out_dir)
    if !(@saved_identifiers.any? {|i| i.include? identifier})
      # puts "Saving #{identifier}"
      File.open(out_dir+'/'+identifier+'.md','w') { |f| f.puts content}
      @saved_identifiers += [identifier]
    end
  end

  def save_elements_to_file (name, content, out_dir)
    File.open(out_dir+'/'+name+'.el','w') { |f| f.puts content}
  end

  def save_variables_to_file (name, content, out_dir)
    File.open(out_dir+'/'+name+'.var','w') { |f| f.puts content}
  end

  # strips enclosing '"', ']', and '[' from uri
  def strip_enclosing_chars_from_element_uri(eu)
    peu = eu.gsub("\"","")
    peu = peu.gsub("[","")
    peu = peu.gsub("]","")
    return peu
  end

  # returns the pair [identifier, id] from a single element uri (/gdc/md/<project>/obj/<obj>/elements?id=<id>)
  def identifier_id_pair_from_element_uri(pid, eu)
    peu = eu.gsub("gdc/md/#{pid}/obj/","")
    peu = strip_enclosing_chars_from_element_uri(peu)
    id = peu.scan(/[0-9]+/)[1]
    uri = eu.gsub(/\/elements/,"")
    uri = uri.gsub(/\?id=[0-9]+/,"")
    uri = strip_enclosing_chars_from_element_uri(uri)
    identifier = identifier(uri)
    return [identifier, id]
  end

  # returns all label identifiers for a specified attribute
  def attribute_label_identifiers (identifier)
    attr = content(identifier)
    labels = attr['attribute']['content']['displayForms']
    return labels.map {|e| e['meta']['identifier']}
  end

  # returns label elements uri
  def label_elements_uri (identifier)
    label_uri = uri(identifier)
    return "#{label_uri}/elements"
  end

  # returns label value for a specified id
  def label_element_value (identifier, id)
    elements_uri = label_elements_uri(identifier)
    response = GoodData::get("#{elements_uri}?id=#{id}")
    if !(response['attributeElements']['elements'].empty?)
        return response['attributeElements']['elements'][0]['title']
    else
      puts "WARNING: label #{label_identifier} doesn't contain element id=#{id}"
    end
  end

  # returns all {value=>id} pairs of a label
  def label_element_values (identifier)
    value_to_uri = {}
      elements_uri = label_elements_uri(identifier)
    response = GoodData::get(elements_uri)
    label_uri = response['attributeElements']['elementsMeta']['attributeDisplayForm']
    label_identifier = identifier(label_uri)
    if !(response['attributeElements']['elements'].empty?)
      values = response['attributeElements']['elements']
      values.each {
        |pair|
        uri = pair['uri']
        value_to_uri[pair['title']] = uri.gsub(/^.*?\?id=/,'')
      }
    else
      puts "WARNING: label #{label_identifier} doesn't contain any elements"
    end
    return value_to_uri
  end

  def primary_label(identifier)
    label_identifier = ""
    label_identifiers = attribute_label_identifiers(identifier)
    case
      when label_identifiers.size > 1
        # there are multiple labels per
        label_identifier = @primary_labels[identifier]
        if label_identifier.nil? or label_identifier.length <=0
          raise "The attribute #{identifier} has multiple labels. You must specify the primary label for it."
        end
      when label_identifiers.size == 1
        label_identifier = label_identifiers[0]
      else
        raise "The attribute #{identifier} has no labels. There is no way to identify its elements."
    end
    return label_identifier
  end

  attr_accessor :identifier_to_uri , :uri_to_identifier, :content_by_identifier, :processed_identifiers,
                :saved_identifiers, :element_uris, :accepted_categories, :primary_labels
  
end