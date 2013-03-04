require 'gooddata'
require 'gooddata/model'
require 'gooddata/client'
require 'json'
require 'logger'
require '../lib/gdc_rest_api_iterator'

class GdcExporter < GdcRestApiIterator


  # primary labels is the hash {attribute identifier => primary label identifier} that determines which label
  # is used for translation of an element id to a (unique) value
  # in other word this si the label that uniquely identifies every value of the attribute
  # no primary label is necessary for most attributes that have just one label
  def initialize (primary_labels)
    @primary_labels = primary_labels
    super()
  end

  def preprocess_md_object(content)
    category = content.keys.first
    case
      when category.eql?("metric")
        content[category]['content'].delete('objects')
        content[category]['content'].delete('tree')
      when category.eql?("report")
        content[category]['content']['definitions'] = [content[category]['content']['definitions'].last]
    end
    return content
  end

  def export_objects(pid, identifiers, out_dir)
    identifiers.each {
      |i|
      export(pid, i, out_dir)
    }
    retrieve_elements(pid, out_dir)
  end

  def export(pid, identifier, out_dir)
    @processed_identifiers+=[identifier]
    content = content(identifier)
    content = preprocess_md_object(content)
    category = content.keys.first
    #puts "Inspecting #{identifier} - #{category}"
    if @accepted_categories.include? category
      content_json = content.to_json
      element_uris = content_json.scan(/["|\[]\/gdc\/md\/#{pid}\/obj\/[0-9]+\/elements\?id=[0-9]+["|\]]/)
      element_uris = element_uris.uniq
      element_uris.each {
          |eu|
        @element_uris += [strip_enclosing_chars_from_element_uri(eu)]
        content_json = content_json.gsub(strip_enclosing_chars_from_element_uri(eu),
                                         "%element%#{identifier_id_pair_from_element_uri(pid, eu).join(',')}%")
      }
      uris = content_json.scan(/["|\[]\/gdc\/md\/#{pid}\/obj\/[0-9]+["|\]]/)
      uris = uris.uniq
      uris.each {
        |uri|
        stripped_uri = strip_enclosing_chars_from_element_uri(uri)
        id = identifier(stripped_uri)
        content_json = content_json.gsub(stripped_uri, "%identifier%#{id}%")
        if !(@processed_identifiers.any? {|i| i.include? id})
          export(pid, id, out_dir)
        end
      }
      save_md_object_to_file(identifier, content_json, out_dir)
    end
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