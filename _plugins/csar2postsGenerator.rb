require 'rubygems'
require 'zip'
require 'nokogiri'
require 'date'
require 'cgi'

module CSAR2Posts

  class CSARPost

    attr_reader :postName
    attr_reader :postType
    attr_reader :postPictureSmall
    attr_reader :postPictureLarge
    attr_reader :postCSAR

    def initialize(postName, postType, postPictureSmall, postPictureLarge, postCSAR)
      puts "Creating CSARPost:"
      puts postName 
      puts postType 
      puts postPictureSmall 
      puts postPictureLarge
      puts postCSAR
      @postName = postName
      @postType = postType
      @postPictureSmall = postPictureSmall
      @postPictureLarge = postPictureLarge
      if postPictureLarge != nil and postType == "nt" and postPictureLarge != "/img/nodetype.png"
        @imgUrlPrefix = postPictureLarge[0,postPictureLarge.index(CGI.escape(@postName))]
        @imgUrlSuffix = postPictureLarge[postPictureLarge.index(CGI.escape(@postName)) + CGI.escape(@postName).size, postPictureLarge.size - 1]
      else
        @imgUrlPrefix = ""
        @imgUrlSuffix = ""
      end
      @postCSAR = postCSAR
      @readableName = postName[postName.index("}") + 1, postName.size - 1]
    end

    # Writes itself into the _post folder of the given site, with the following schema:
    #---
    #layout: default
    #modal-id: 6
    #date: 2014-07-15
    #img: submarine.png
    #alt: image-alt
    #project-date: April 2014
    #client: Start Bootstrap
    #category: Web Development
    #description: Use this area of the page to describe your project. The icon above is part of a free icon set by <a href="https://sellfy.com/p/8Q9P/jV3VZ/">Flat Icons</a>. On their website, you can download their free set with 16 icons, or you can purchase the entire set with 146 icons for only $12!
    #---
    def write(site, modal_id)
      data = "---"
      data << "\n"
      data << "layout: default"
      data << "\n"
      data << "modal-id: " + modal_id.to_s
      data << "\n"
      data << "date: " + Date.today.strftime("%Y") + "-" + Date.today.strftime("%m") + "-" + Date.today.strftime("%d")
      data << "\n"
      data << "qname: " + @postName.gsub("{","=").gsub("}","§").to_s
      data << "\n"
      data << "img: " + @postPictureLarge
      data << "\n"
      data << "img-prefix: " + @imgUrlPrefix.to_s
      data << "\n"
      data << "img-suffix: " + @imgUrlSuffix.to_s
      data << "\n"
      data << "alt: image-alt"
      data << "\n"
      data << "project-date: " + Date.today.strftime("%B") + " " + Date.today.strftime("%Y")
      data << "\n"
      data << "client: " + CGI.escape(@readableName.to_s)
      data << "\n"
      data << "category: " + @postType.to_s
      data << "\n"
      data << "description: Generated"
      data << "\n"
      data << "csar: " + @postCSAR
      data << "\n"
      data << "---"
	
      puts "Writing following post data:"
      puts data

      # create post file
      postFileName = Date.today.strftime("%Y") + "-" + Date.today.strftime("%m") + "-" + Date.today.strftime("%d") + "-" + @postType.to_s + "-" + CGI.escape(@postName.to_s) + ".markdown"
      postFilePath = site.in_source_dir("_posts/" + postFileName)
      postFile = File.open(postFilePath, "w")
      postFile.write(data)

    end

    def isValid()
	valid = true
	if @postName == nil
		valid = false
	end
	if @postPictureLarge == nil
		valid = false
	end
	if @readableName == nil 
		valid = false
	end
	if @postType == nil 
		valid = false
	end
	if @postCSAR == nil 
		valid = false
	end
	return valid
    end

  end

  class CSAR2PostsGenerator < Jekyll::Generator

    def initialize(site)
      @site = site
      @csarPath = "/home/kalman/Documents/svn/SmartOrchestra/SmartOrchestra/"
      FileUtils.mkdir_p(@site.in_source_dir("downloads/"))
      puts "Initialized CSAR2PostsGenerator with CSAR folder path: " + @csarPath
    end

    def generate(site)

      postsArray = Array.new
      # search for csar's
      Dir.glob("#{@csarPath}/**/*.csar") do |csarFile|
        definitionsFilePath = self.fetchDefinitionsFilePathFromCSAR(csarFile)
        puts "Found definitionsFilePath at " + definitionsFilePath
        definitionsXmlFile = Nokogiri::XML(self.fetchFileFromFromZip(csarFile,definitionsFilePath))
        puts "Parsed Entry-Definitions File"
        entityXmlElement = self.fetchTOSCAEntityElement(definitionsXmlFile)
        puts "Fetched entityXmlElement"

        if entityXmlElement == nil
          next
        end

        postName = nil
        postType = nil
        postPictureSmall = nil
        postPictureLarge = nil
        postCSAR = nil

        # write csar into downloads dir and create postCSAR path
        postCSARTemp = site.in_source_dir("downloads/" + (File.basename csarFile))
        siteCSARFile = File.open(postCSARTemp, 'w')
        FileUtils.cp(csarFile,siteCSARFile)
        # siteCSARFile.write(csarFile)
	postCSAR = "/downloads/" + (File.basename postCSARTemp)

        # TODO: load images, save them in img folder, reference in post (ST, RT und AT missing)

        case entityXmlElement.xpath("local-name()")
        when "ServiceTemplate"
          serviceTemplateName = entityXmlElement.attr("name")
          serviceTemplateId = entityXmlElement.attr("id")
          serviceTemplateTargetNS = entityXmlElement.attr("targetNamespace")
          postName = "{" + serviceTemplateTargetNS + "}" + serviceTemplateId
	  postPictureLarge = "/img/servicetemplate.png"
          postType = "st"
        when "NodeType"
          nodeTypeName, nodeTypeTargetNS, nodeTypeIconSmall, nodeTypeIconLarge = self.fetchNodeTypeData(entityXmlElement)
          postName = "{" + nodeTypeTargetNS + "}" + nodeTypeName
	  postType = "nt"
          if nodeTypeIconLarge != nil
	      postPictureLarge = self.fetchImageFromCSARIntoSite(site,csarFile, postName, nodeTypeIconLarge, nodeTypeTargetNS, postType)
	    if postPictureLarge == nil
              postPictureLarge = "/img/nodetype.png"
            end
          end
          
        when "RelationshipType"
          relationshipTypeName = entityXmlElement.attr("name")
          relationshipTypeTargetNS = entityXmlElement.attr("targetNamespace")
          postName = "{" + relationshipTypeTargetNS + "}" + relationshipTypeName
	  postPictureLarge = "/img/relationshiptype.png"
          postType = "rt"
        when "ArtifactType"
          artifactTypeName = entityXmlElement.attr("name")
          artifactTypeTargetNS = entityXmlElement.attr("targetNamespace")
          postName = "{" + artifactTypeTargetNS + "}" + artifactTypeName
	  postPictureLarge = "/img/artifacttype.png"
          postType = "at"
        else next
        end

        postsArray.push(CSARPost.new(postName, postType, postPictureSmall, postPictureLarge, postCSAR))


      end

      self.writeCSARPosts(postsArray, site)
    end

    def fetchImageFromCSARIntoSite(site, csarFile, postName, nodeTypeIconLarge, nodeTypeTargetNS, type)
	imgPath = nil
	case type
	when "st"
		imgPath = "servicetemplates"
	when "nt"
		imgPath = "nodetypes"
	when "rt"
		imgPath = "relationshiptypes"
	when "at"
		imgPath = "artifacttypes"
	end
	postPictureLargeTemp = site.in_source_dir("img/"+ imgPath +"/" + CGI.escape(postName) + "/" + (File.basename nodeTypeIconLarge))
        fileData = self.fetchFileFromFromZip(csarFile, nodeTypeIconLarge.sub(nodeTypeTargetNS, CGI.escape(nodeTypeTargetNS)))
        #puts fileData
        if fileData != nil
        	FileUtils.mkdir_p(File.dirname(postPictureLargeTemp)) unless File.exists?(File.dirname(postPictureLargeTemp))
        	File.open(postPictureLargeTemp, "w").write(fileData)
        	postPictureLarge = "/img/"+ imgPath +"/" + CGI.escape(postName) + "/" + (File.basename nodeTypeIconLarge)
		return postPictureLarge            
        end
    end

    def writeCSARPosts(posts, site)
      modalCounter = 1
      posts.each{
        |post|
	if post.isValid
         post.write(site, modalCounter)
	 modalCounter += 1
	end
      }
    end

    def fetchNodeTypeData(entityXmlElement)
      nodeTypeName = entityXmlElement.attr("name")
      nodeTypeTargetNS = entityXmlElement.attr("targetNamespace")
      nodeTypeIconPath = "nodetypes/" + URI.encode(nodeTypeTargetNS) + "/" + nodeTypeName + "/appearance/"
      nodeTypeIconSmall = nodeTypeIconPath + "smallIcon.png"
      nodeTypeIconLarge = nodeTypeIconPath + "bigIcon.png"
      return nodeTypeName, nodeTypeTargetNS, nodeTypeIconSmall, nodeTypeIconLarge
    end

    def fetchTOSCAEntityElement(definitionsXmlFile)
      puts "Trying to find entityXmlElement"
      sTXpath = "//*[local-name()='Definitions']/*[local-name()='ServiceTemplate']"
      nTXpath = "//*[local-name()='Definitions']/*[local-name()='NodeType']"
      rTXpath = "//*[local-name()='Definitions']/*[local-name()='RelationshipType']"
      aTXpath = "//*[local-name()='Definitions']/*[local-name()='ArtifactType']"

      if !definitionsXmlFile.xpath(sTXpath).empty?
        puts "Found ServiceTemplate Element"
        #found ServiceTemplate definitions
        return definitionsXmlFile.xpath(sTXpath)[0];
      elsif !definitionsXmlFile.xpath(nTXpath).empty?
        puts "Found NodeType Element"
        #found NodeType definitions
        return definitionsXmlFile.xpath(nTXpath)[0];
      elsif !definitionsXmlFile.xpath(rTXpath).empty?
        puts "Found RelationshipType Element"
        #found RelationshipType definitions
        return definitionsXmlFile.xpath(rTXpath)[0];
      elsif !definitionsXmlFile.xpath(aTXpath).empty?
        puts "Found ArtifactType Element"
        #found ArtifactType definitions
        return definitionsXmlFile.xpath(aTXpath)[0];
      end

    end

    def fetchDefinitionsFilePathFromCSAR(csarFile)
      # for each csarFile fetch the TOSCA-Meta
      puts "Trying to detch Definitions document inside CSAR " + csarFile
      ::Zip::File.open(csarFile) do |csarZip|
        toscaMetaEntry = csarZip.glob('TOSCA-Metadata/TOSCA.meta').first
        (toscaMetaEntry.get_input_stream.read).each_line do |line|
          puts "Found line: " + line
          if line.include? "Entry-Definitions"
            return line.split(":")[1].strip!
          end
        end



      end
    end

    def fetchFileFromFromZip(zipFile, relFilePath)
      puts "Looking for file " + relFilePath + " in " + zipFile
      if ::Zip::File.open(zipFile).glob(relFilePath).first != nil
        return ::Zip::File.open(zipFile).glob(relFilePath).first.get_input_stream.read
      end
    end
  end
end
