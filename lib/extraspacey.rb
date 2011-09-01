# ExtraSpacey: Extra Space data feed fetcher
# Handles connecting to the feed and converting the XML into ruby hash using HTTParty

class ExtraSpacey
  begin
    include HTTParty
    base_uri 'http://www.extraspace.com/data-services'
  rescue
    raise "ExtraSpacey needs to HTTParty!\n#{$!}"
  end
  
  @@feed_url = '/site-xml-tt.aspx'
  
  def self.get_sites
    @@sites ||= get_feed(@@feed_url)
  end
  
  def self.get_site(id)
    return nil if id.nil?
    get_feed @@feed_url +'?SiteID='+ id.to_s
  end
  
  def self.es_description
    "Extra Space Storage is a growth-oriented company creating a new standard in the self-storage industry. Both customers and communities benefit from Extra Space Storage's professional approach to storage. Featuring attractive, convenient and secure facilities operated by professional managers, Extra Space Storage seeks to change the association of self storage as a temporary holding place for rarely-used things to a desirable, safe, and customer-oriented facility perfectly suited for maintaining and accessing valued personal and business possessions."
  end
  
  private
  
  def self.get_feed(url)
    get(url)['ESSsites']['Site']
  end
  
end
