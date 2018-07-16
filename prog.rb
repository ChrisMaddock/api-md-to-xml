require 'nokogiri'
require 'cgi'

def resolveLinks(captures)

    if captures.length > 3
        puts "more than one link"
    end

    title = captures[1]
    link = captures[2]

    if title.start_with?("!INCLUDE")
        return nil
    end

    if link.start_with?("~/docs")
        link.sub!("~/docs", "https://docs.microsoft.com/dotnet")
    end

    return "<see href=\"%s\">%s</see>" % [CGI::escapeHTML(link), CGI::escapeHTML(title)]

end

files = Dir["C:/Users/Chris/Documents/git/dotnet-api-docs/xml/**/*.xml"].select { |fn| File.file?(fn) }
tag = "summary"


files.each do |file|
    fileIn = File.read(file).force_encoding(::Encoding::UTF_8)
    xml = Nokogiri::XML(fileIn)

    xml.xpath("//%s" % tag).each do |node|
        matches = /(\[([^\]]*)]\(([^\)]*)\))/.match(node.content)

        if matches.nil?
            next
        end

        newLink = resolveLinks(matches.captures)
        
        if newLink.nil?
            next
        end
        oldLink = CGI::escapeHTML(matches.captures[0])

        puts file
        puts "Replacing: %s" % oldLink

        regexStr = "(?<=<%s>)(.*?%s.*)(?=</%s>)" % [tag, Regexp.escape(oldLink), tag]

        regex = Regexp.new(regexStr)

        matches = regex.match(fileIn)

        oldSummary = matches.captures[0]
        newSummary = oldSummary.gsub(CGI::escapeHTML(oldLink), newLink)
        fileIn.gsub!(CGI::escapeHTML(oldSummary), newSummary)

        File.write(file, fileIn)

      end
end
