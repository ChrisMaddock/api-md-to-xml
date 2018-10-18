require 'nokogiri'
require 'cgi'
require 'net/http'
require 'uri'
require 'final_redirect_url'

def resolveLinks(captures)

    if captures.length > 3
        puts "more than one link"
    end

    title = captures[1]
    link = captures[2]

    if title.start_with?("!INCLUDE")
        return nil
    end

    # Redirection
    if link.start_with?("http")
        begin
            redirected = FinalRedirectUrl.final_redirect_url(link)
            puts "Redirected is: [#{redirected}]"
            link = redirected.to_s
        rescue 
            puts "EXCEPTION"
        end
    end

    if link.start_with?("http://")
        begin
            url = URI.parse(link.sub("http://", "https://"))
            req = Net::HTTP::Get.new(url.path)
            response = Net::HTTP.start( url.host, url.port ) { |http| http.request( req ) }
            code = response.code

            if (code == "200")
                link.sub!("http://", "https://")
            end

        rescue  #fail silently for now
        end
    end

    if link.start_with?("https://docs.microsoft.com/en-us")
        link.sub!("/en-us", "")
    end

    if link.start_with?("~/docs")
        link.sub!("~/docs", "https://docs.microsoft.com/dotnet")
        if (link.end_with?(".md"))
            link.sub!(".md", "")
        end
    elsif link.start_with?("/")
        link.sub!("/", "https://docs.microsoft.com/")
        if (link.end_with?(".md"))
            link.sub!(".md", "")
        end
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

        if matches.nil?
            next
        end

        oldSummary = matches.captures[0]
        newSummary = oldSummary.gsub(CGI::escapeHTML(oldLink), newLink)
        fileIn.gsub!(CGI::escapeHTML(oldSummary), newSummary)

        File.write(file, fileIn)

      end
end
