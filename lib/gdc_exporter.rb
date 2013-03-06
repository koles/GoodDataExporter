require 'gooddata'
require 'gooddata/model'
require 'gooddata/client'
require 'json'
require 'logger'
require '../lib/gdc_rest_api_iterator'

class GdcExporter < GdcRestApiIterator

  @prompt_identifiers = []

  # primary labels is the hash {attribute identifier => primary label identifier} that determines which label
  # is used for translation of an element id to a (unique) value
  # in other word this si the label that uniquely identifies every value of the attribute
  # no primary label is necessary for most attributes that have just one label
  def initialize (primary_labels)
    @prompt_identifiers = []
    super()
    @primary_labels = primary_labels
  end

  def preprocess_md_object(content)
    category = content.keys.first
    case
      when category.eql?("metric")
        content[category]['content'].delete('objects')
        content[category]['content'].delete('tree')
      when category.eql?("reportDefinition")
        content[category]['content']['filters'].delete('objects')
        content[category]['content']['filters'].delete('tree')
      when category.eql?("report")
        content[category]['content']['definitions'] = [content[category]['content']['definitions'].last]
      when category.eql?("prompt")
        @prompt_identifiers += [content[category]['meta']['identifier']]
    end
    return content
  end

  def export(pid, identifiers, out_dir)
    identifiers.each {
      |i|
      export_object(pid, i, out_dir)
    }
    retrieve_prompt_items(pid, out_dir)
    retrieve_elements(pid, out_dir)
  end

  def replace_element_uris(pid, json)
    element_uris = json.scan(/["|\[]\/gdc\/md\/#{pid}\/obj\/[0-9]+\/elements\?id=[0-9]+["|\]]/)
    element_uris = element_uris.uniq
    element_uris.each {
        |eu|
      @element_uris += [strip_enclosing_chars_from_element_uri(eu)]
      json = json.gsub(strip_enclosing_chars_from_element_uri(eu),
                                       "%element%#{identifier_id_pair_from_element_uri(pid, eu).join(',')}%")
    }
    return json
  end

  def replace_uris(pid, json, out_dir)
    uris = json.scan(/["|\[]\/gdc\/md\/#{pid}\/obj\/[0-9]+["|\]]/)
    uris = uris.uniq
    uris.each {
      |uri|
      stripped_uri = strip_enclosing_chars_from_element_uri(uri)
      id = identifier(stripped_uri)
      json = json.gsub(stripped_uri, "%identifier%#{id}%")
      if !(@processed_identifiers.any? {|i| i.include? id})
        export_object(pid, id, out_dir)
      end
    }
    return json
  end

  def export_object(pid, identifier, out_dir)
    @processed_identifiers+=[identifier]
    content = content(identifier)
    content = preprocess_md_object(content)
    category = content.keys.first
    puts "Exporting #{identifier} - #{category}"
    if @accepted_categories.include? category
      content_json = content.to_json
      content_json = replace_element_uris(pid, content_json)
      content_json = replace_uris(pid, content_json, out_dir)
      save_md_object_to_file(identifier, content_json, out_dir)
    end
  end

  def retrieve_prompt_items(pid, out_dir)
    variables_array = []
    prompt_uris = @prompt_identifiers.uniq.map {|i| uri(i)}
    variables_search = {'variablesSearch'=>{'variables'=>prompt_uris,'context'=>[]}}
    result = GoodData::post("/gdc/md/#{pid}/variables/search", variables_search)
    result = result['variables'].select {|e| e['level'].eql?('project')}
    result.each {
      |r|
      r.delete('related')
      r.delete('tree')
      r.delete('objects')
      r.delete('uri')
      json = r.to_json
      json = replace_element_uris(pid, json)
      json = replace_uris(pid, json, out_dir)
      variables_array += [JSON.parse(json)]
    }
    variables = {'variables'=>variables_array}
    save_variables_to_file('variables', variables.to_json, out_dir)
  end

  def retrieve_elements(pid, out_dir)
    @element_uris = @element_uris.uniq
    element_values = {}
    @element_uris.each {
      |eu|
      identifier, id = identifier_id_pair_from_element_uri(pid, eu)
      label_identifier = primary_label(identifier)
      label_value = label_element_value(label_identifier, id)
      if element_values[label_identifier].nil?
        element_values[label_identifier] = {id=>label_value}
      else
        element_values[label_identifier][id] = label_value
      end
    }
    save_elements_to_file('used_elements', element_values.to_json, out_dir)
  end

end