# (c) 2011 Diego E. Salazar for USSSL
# ExtraSpaceable: An AR plugin to keep models up to date with Extra Space Site data using the ExtraSpacey XML Feed wrapper
require 'extraspacey'

module ExtraSpaceable #:nodoc:
  
  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods

    def extra_spaceable
      require 'extraspacey'
      extend  ExtraSpaceable::SingletonMethods
      include ExtraSpaceable::InstanceMethods
      has_one :extra_space_site
      named_scope :es_listings, :conditions => ['title ILIKE ?', 'extra space%']
    end

  end  # END ClassMethods
  
  module SingletonMethods
    
    # find a listing that matches an extra space site or create it
    # update or create the associated extra_space_site
    def match_extra_spaces_to_listings!
      log 'Getting Extra Space Sites...'
      @sites = ExtraSpacey.get_sites
      @total = @sites.size
      
      log "About to process #{@total} sites...\n\n"
      
      @sites.each_with_index do |site, i|
        next if site['SiteID'].blank?
        width, length = *site['UnitDimensions'].downcase.split('x').map(&:to_i)
        conditions    = ['city = ? AND full_state = ? AND zip = ?', site['City'], site['State'], site['PostalCode']]
        listing       = Listing.es_listings.first(:conditions => conditions) || Listing.new(listing_attr(site, width, length))
        
        listing.process_extra_space site, width, length, i, @total
      end
      
      puts 'Done.'
    end
    
    private

    def listing_attr(site, w, l)
      {
        :title       => 'Extra Space',
        :city        => site['City'],
        :full_state  => site['State'],
        :zip         => site['PostalCode'],
        :description => ExtraSpacey.es_description,
        # these ImageURLs come with &width=319&height=240 appended to them. We want the full img.
        :sizes_attributes => {
          '0' => size_attr(site, w, l)
        }
      }
    end
    
    def size_attr(site, width, length)
      {
        :title  => 'Indoor',
        :width  => width,
        :length => length,
        :sqft   => (width * length),
        :price  => (site['LowestRate'].to_i * 100)
      }
    end
    
    def log(msg)
      puts "-----> #{msg}"
    end

    def percent_of(is, of)
      "#{sprintf("%.2f", ((is + 1).to_f / of.to_f * 100))}%"
    end
    
  end # END SingletonMethods
  
  module InstanceMethods
    
    # creates a new Listing and as necessary a Size and ExtraSpaceSite
    def process_extra_space(site, width, length, i = nil, total = nil)
      if self.new_record?
        self.build_extra_space_site underscore_keys(site)
        pic = self.pictures.build
        pic.image = open(site['ImageURL'].split('&').first)
        self.save
        
        log_percent i, total, "Created new Listing (#{self.id}) and ExtraSpaceSite.\n\n"
      else
        log "Found Listing #{self.id}."
        
        self.description = ExtraSpacey.es_description if self.description.blank?
        self.logo = nil
        pic = self.pictures.build
        pic.image = open(site['ImageURL'].split('&').first)
        self.save
        
        if self.extra_space_site.nil?
          self.create_extra_space_site underscore_keys(site)
          
          log_percent i, total, "Created ExtraSpaceSite.\n\n"
          
        elsif site['LowestRate'].to_f != self.extra_space_site.lowest_rate
          self.extra_space_site.update_attributes underscore_keys(site)
          size = self.sizes.first(:conditions => { :width => width, :length => length })
          
          if size
            size.update_attribute :price, (site['LowestRate'].to_i * 100)
            log 'Updated Size price'
          else
            self.sizes.create self.class.send(:size_attr, site, width, length)
            log 'Created Size'
          end
          
          log_percent i, total, "Updated ExtraSpaceSite\n\n"
        else
          log_percent i, total, "Already up to date\n\n"
        end
      end
    end
    
    # Call the XML feed to get a single site.
    def get_extra_space_site(id = nil)
      return if id && self.extra_space_site.nil?
      ExtraSpacey.get_site(id || self.extra_space_site.site_id)
    end
    
    private
    
    def underscore_keys(site)
      s = {}
      site.each { |k, v| s.store k.underscore, (k == 'UnitDimensions' ? v.downcase : v) }; s
    end
    
    def log(msg)
      self.class.send :log, msg
    end
    
    def log_percent(is, of, msg)
      log "#{is ? self.class.send(:percent_of, is, of) + ' ' : ''}#{msg}"
    end
  
  end # END InstanceMethods
  
end