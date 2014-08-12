require 'rexml/document'
require 'net/https'
require 'uri'
include REXML

class GoConfig
  def initialize(uri, user, password)
    @user = user
    @password = password
    @uri = uri
    getRemoteXML
  end
  def getRemoteXML()
    uriObj = URI.parse(@uri)
    http = Net::HTTP.new(uriObj.host, uriObj.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Get.new(uriObj.request_uri)
    request.basic_auth(@user, @password)
    response = http.request(request)
    if response.code != "200"
      puts "Error:"
      puts response.body
      exit 1
    end
    file =  response.body
    @config = Document.new(file, {:raw => :all, :attribute_quote => :quote})
    @configHash = response.header["x-cruise-config-md5"]
  end
  def cloneTemplate(sourceTemplate, destinationTemplate)
    sourceTemplateObj = XPath.first(@config, ".//templates/pipeline[@name='#{sourceTemplate}']")
    if sourceTemplateObj == nil
      puts "Error:"
      puts "Source template #{sourceTemplate} does not exit in configuration xml."
      exit 1
    end
    templateClone = sourceTemplateObj.deep_clone()
    templateClone.attributes["name"] = destinationTemplate
    templatesObj = XPath.first(@config, ".//templates")
    templatesObj.add(templateClone)
  end
  def save()
    uriObj = URI.parse(@uri)
    http = Net::HTTP.new(uriObj.host, uriObj.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Post.new(uriObj.path)
    request.basic_auth @user, @password
    request.set_form_data({'xmlFile' => @config, 'md5' => @configHash})
    response = http.request(request)
    if response.code == "200" and response.body.include? "successfully"
      puts "Operation successfully completed!"
    else
      puts "Error:"
        puts response.body
      exit 1
    end
  end

end
def showUsage  
  puts "Clone existing template based on SOURCE_TEMPLATE and DESTINATION_TEMPLATE environment variables"
  puts "#{$0} clone"
  puts "Example: #{$0} clone"
end

#==========================================================================================================

unless ARGV.length == 1
  showUsage
  exit
end

if ARGV.length == 1 and ARGV[0] != "clone"
  puts "Error:"
  puts "Was expecting \"clone\" as first argument"
  showUsage
  exit 1
end

password = ENV['API_PASS']
user = ENV['API_USER']
uri = ENV['GO_SERVER_URL'] + "api/admin/config.xml"

goConfigObj = GoConfig.new(uri, user, password)
goConfigObj.cloneTemplate(ENV['SOURCE_TEMPLATE'], ENV['DESTINATION_TEMPLATE'])
goConfigObj.save()