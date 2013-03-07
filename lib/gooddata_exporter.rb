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

  def attributes_with_multiple_labels(pid)
    attributes_with_multiple_labels = {}
    response = GoodData::get("/gdc/md/#{pid}/query/attributes")
    response['query']['entries'].each {
        |a|
      uri = a['link']
      identifier = identifier(uri)
      label_identifiers = attribute_label_identifiers(identifier)
      if label_identifiers.size > 1
        attributes_with_multiple_labels[identifier] = label_identifiers
      end
    }
    return attributes_with_multiple_labels
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
    if @content_by_identifier.keys.include? identifier
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
    if !(@saved_identifiers.include? identifier)
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
      if !(@processed_identifiers.include? id)
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

class GdcImporter < GdcRestApiIterator

  @element_values = {}
  @element_ids = {}

  # primary labels is the hash {attribute identifier => primary label identifier} that determines which label
  # is used for translation of an element id to a (unique) value
  # in other word this si the label that uniquely identifies every value of the attribute
  # no primary label is necessary for most attributes that have just one label
  def initialize (primary_labels)
    @element_values = {}
    @element_ids = {}
    super()
    @primary_labels = primary_labels
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
    identifier = json[json.keys.first]['meta']['identifier']
    puts "Saving #{identifier}"
    uri = ""
    begin
      uri = uri(identifier)
    rescue
      uri = ""
    end
    if (uri.nil? or uri.size <=0)
      response = GoodData::post("/gdc/md/#{pid}/obj", json)
      uri = response["uri"]
      response = GoodData::get(uri)
      # Here the object has auto generated identifier, we want to update it
      # we have to retrieve it with an extra GET to not cache it with the wrong identifier
      response[response.keys.first]['meta']['identifier'] = json[response.keys.first]['meta']['identifier']
    else
      response = json
    end
    GoodData::post(uri, response)
    return uri
  end

  def replace_identifiers(pid, content, overwrite, out_dir)
    identifier_macros = content.scan(/\%identifier\%.*?\%/).uniq
    identifier_macros.each {
        |s|
      inner_identifier = identifier_from_macro(s)
      inner_uri = ""
      begin
        inner_uri = uri(inner_identifier)
      rescue
        inner_uri = ""
      end
      if(inner_uri.nil? or inner_uri.size() <= 0 or overwrite)
        inner_uri = import_object(pid, inner_identifier, overwrite, out_dir)
      end
      content = content.gsub(s, inner_uri)
    }
    return content
  end

  def replace_elements(content)
    element_macros = content.scan(/\%element\%.*?\%/).uniq
    element_macros.each {
        |s|
      attr_identifier, id = identifier_value_from_macro(s)
      attr_uri = uri(attr_identifier)
      element_identifier = primary_label(attr_identifier)
      element_value = @element_ids[element_identifier][id]
      values = label_values(element_identifier)
      element_id = values[element_value]
      if element_id.nil?
        raise "The label #{element_identifier} doesn't contain the value \'#{element_value}\'. Please load correct data to the target project."
      end
      content = content.gsub(s, "#{attr_uri}/elements?id=#{element_id}")
    }
    return content
  end

  def import(pid, identifiers, overwrite, out_dir)
    @element_ids = JSON.parse(File.open(File.join(out_dir,"used_elements.el"), "rb") {|f| f.read})
    identifiers.each {
        |e|
      import_object(pid, e, overwrite, out_dir)
    }
    import_variable_items(pid, overwrite, out_dir)
  end

  def import_object(pid, identifier, overwrite, out_dir)
    puts "Importing #{identifier}"
    uri = ""
    begin
      uri = uri(identifier)
    rescue
      uri = ""
    end
    filename = File.join(out_dir,"#{identifier}.md")
    if(uri.nil? or uri.size <= 0 or (overwrite and File.exists?(filename) and (not @saved_identifiers.include?(identifier))))
      content = File.open(filename, "rb") {|f| f.read}
      content = remove_object_keys (content)
      content = replace_identifiers(pid, content, overwrite, out_dir)
      content = replace_elements(content)
      uri = save_md_object_to_gd(pid, JSON.parse(content))
      @saved_identifiers += [identifier]
    end
    return uri
  end

  def import_variable_items(pid, overwrite, out_dir)
    content = JSON.parse(File.open(File.join(out_dir,"variables.var"), "rb") {|f| f.read})
    variables = content['variables'].each {
        |v|
      v['related']="/gdc/projects/#{pid}"
      content = {'variables'=>[v]}.to_json
      content = replace_identifiers(pid, content, overwrite, out_dir)
      content = replace_elements(content)
      begin
        GoodData::post("/gdc/md/#{pid}/variables/project", JSON.parse(content))
      rescue
        puts "Variable answer already exists!"
      end
    }
  end


end