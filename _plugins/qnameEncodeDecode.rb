# _plugins/url_encode.rb
require 'liquid'
require 'uri'

# Percent encoding for URI conforming to RFC 3986.
# Ref: http://tools.ietf.org/html/rfc3986#page-12
module QNameEncodeDecode
  def qname_encode(qname)
    return qname.gsub("{","=").gsub("}","§")
  end

  def qname_decode(qname)
    return qname.gsub("=","{").gsub("§","}")
  end
end

Liquid::Template.register_filter(QNameEncodeDecode)
