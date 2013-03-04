require 'gooddata'
require 'gooddata/model'
require 'gooddata/client'
require 'json'
require 'logger'
require '../lib/gdc_rest_api_iterator'

class GdcImporter < GdcRestApiIterator

  @element_values = {}

  # primary labels is the hash {attribute identifier => primary label identifier} that determines which label
  # is used for translation of an element id to a (unique) value
  # in other word this si the label that uniquely identifies every value of the attribute
  # no primary label is necessary for most attributes that have just one label
  def initialize (primary_labels)
    @primary_labels = primary_labels
    @element_values = {}
    super()
  end

  def label_values(identifier)
    values = @element_values[identifier]
    if values.nil?
      values = label_element_values(identifier)
      @element_values[identifier] = values
    end
    return values
  end

  def identifier_from_macro(macro)
    identifier =  macro.gsub('identifier','')
    identifier =  identifier.gsub('%','')
    return identifier
  end

  def identifier_value_from_macro(macro)
    identifier_value =  macro.gsub('element','')
    identifier_value =  identifier_value.gsub('%','')
    return identifier_value.split(',')
  end

  def remove_object_keys (content)
    json = JSON.parse(content)
    json[json.keys.first]['meta'].delete('uri')
    json[json.keys.first]['meta'].delete('created')
    json[json.keys.first]['meta'].delete('updated')
    json[json.keys.first]['meta'].delete('contributor')
    json[json.keys.first]['meta'].delete('author')
    return json.to_json
  end

  def save_md_object_to_gd(pid, json)
    puts "Saving #{json[json.keys.first]['meta']['identifier']} - #{json}"
    response = GoodData::post("/gdc/md/#{pid}/obj", json)
    uri = response["uri"]
    # Here the object has auto generated identifier, we want to update it
    # we have to retrieve it with an extra GET to not cache it with the wrong identifier
    response = GoodData::get(uri)
    response[response.keys.first]['meta']['identifier'] = json[response.keys.first]['meta']['identifier']
    GoodData::post(uri, response)
    return uri
  end

  def import(pid, identifier, out_dir)
    puts "Processing #{identifier}"
    content = File.open(File.join(out_dir,"#{identifier}.md"), "rb") {|f| f.read}
    content = remove_object_keys (content)
    identifier_macros = content.scan(/\%identifier\%.*?\%/).uniq
    identifier_macros.each {
      |s|
      inner_identifier = identifier_from_macro(s)
      inner_uri = ""
      begin
        inner_uri = uri(inner_identifier)
      rescue
        inner_uri = import(pid, inner_identifier, out_dir)
      end
      content = content.gsub(s, inner_uri)
    }
    element_values = JSON.parse(File.open(File.join(out_dir,"used_elements.el"), "rb") {|f| f.read})
    element_macros = content.scan(/\%element\%.*?\%/).uniq
    element_macros.each {
      |s|
      attr_identifier, id = identifier_value_from_macro(s)
      attr_uri = uri(attr_identifier)
      element_identifier = primary_label(attr_identifier)
      element_value = element_values[element_identifier][id]
      values = label_values(element_identifier)
      element_id = values[element_value]
      if element_id.nil?
        raise "The label #{element_identifier} doesn't contain the value \'#{element_value}\'. Please load correct data to the target project."
      end
      content = content.gsub(s, "#{attr_uri}/elements?id=#{element_id}")
    }
    return save_md_object_to_gd(pid, JSON.parse(content))
  end


end