class Photo
	require 'exifr/jpeg'
	
	 attr_accessor :id, :location
	 attr_writer :contents
	
	def self.mongo_client
   Mongoid::Clients.default
  end

	def find_nearest_place_id(max_meters)
		result = Place.near(@location,max_meters).limit(1).projection(_id:1).first[:_id]
	end

 	def self.find(id)
    doc = Photo.mongo_client.database.fs.find(:_id=>BSON::ObjectId.from_string(id)).first
    return doc ? Photo.new(doc) : nil
  end
	
	def persisted?
    !@id.nil?
  end

	def contents
      Photo.mongo_client.database.fs.find_one(:_id=>BSON::ObjectId.from_string(self.id)).data
  end
	
	def self.all(skip=0, limit=nil)
	
	
		result=self.mongo_client.database.fs.find.skip(skip)
		result=result.limit(limit) if !limit.nil?
		
		photos = []
    result.each do |r|
      photos << Photo.new(r)
    end
    return photos


	end

	def destroy
    f = Photo.mongo_client.database.fs.find_one(:_id=>BSON::ObjectId.from_string(self.id))
    Photo.mongo_client.database.fs.delete_one(f)
  end
	
	def save
    if self.persisted?
      bson_id = BSON::ObjectId.from_string(id.to_s)
      
      description = Hash.new 
      description[:metadata] = Hash.new    
      description[:metadata][:location] = self.location.to_hash    
			description[:metadata][:place] = BSON::ObjectId.from_string(place.id) if place.is_a? Place 

      params = self.class.mongo_client.database.fs.find(_id: bson_id).update_one(:$set => description)
    else
      gps = EXIFR::JPEG.new(@contents).gps
      self.location = Point.new({lng: gps.longitude, lat: gps.latitude})

      description = Hash.new      
      description[:content_type] = "image/jpeg"  
      description[:metadata] = Hash.new    
      description[:metadata][:location] = self.location.to_hash
      description[:metadata][:place] = BSON::ObjectId.from_string(place.id) if place.is_a? Place 

      if @contents.present?
        @contents.rewind
        grid_file = Mongo::Grid::File.new(@contents.read, description)
        id = self.class.mongo_client.database.fs.insert_one(grid_file)        
        self.id = id.to_s  
      end
    end
  end
	
	def initialize(params={})
		if params.size > 0
			@id = params[:_id].nil? ? params[:id].to_s : params[:_id].to_s
		
			unless params[:metadata].nil?
			@place = params[:metadata][:place].nil? ? nil : params[:metadata][:place].to_s
			@location = Point.new(params[:metadata][:location])
			end
			
		end
	end
	
	
		def place
    if !@place.nil?
        Place.find(@place.to_s)
    end
  end
	
def self.find_photos_for_place(place_id)
   		if place_id.is_a?(String)
   			place_id = BSON::ObjectId.from_string(place_id)
   		end
   		self.mongo_client.database.fs.find(:"metadata.place"=>BSON::ObjectId.from_string(place_id.to_s))
   		
   	end

	
	
	def place=(place)
		if place.class == Place
			@place = BSON::ObjectId.from_string(place.id.to_s)
		elsif place.class == String
			@place = BSON::ObjectId.from_string(place)
		else
			@place = place
		end
	end
	
end







