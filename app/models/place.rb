class Place
	
	attr_accessor :id, :formatted_address, :location, :address_components
	
	def self.collection
   self.mongo_client['places']
  end
	
	def self.find_by_short_name(short_name)
    collection.find( { 'address_components.short_name' => short_name })
	end
	
	def self.create_indexes  	
		collection.indexes.create_one({"geometry.geolocation"=>"2dsphere"})  
	end
	
	def self.remove_indexes
		collection.indexes.drop_one("geometry.geolocation_2dsphere")
	end
	
	def self.near (point, max_meters=nil)
		unless max_meters.nil?
			collection.find('geometry.geolocation'=> 
										{:$near=>{
											:$geometry=>point.to_hash,
											:$minDistance=>0,
											:$maxDistance=>max_meters
										 }
										})
		end
	end
	
	def near(max_meters=nil)
		if max_meters.nil?
			self.class.to_places(self.class.near(@location))
		else
			self.class.to_places(self.class.near(@location,max_meters))
		end
	end
	
	def self.all(offset=0,limit=nil)
    result = collection.find.skip(offset)
    result = limit.nil? ? result.to_a : result.limit(limit).to_a
		
		places = []
    result.each do |r|
      places << Place.new(r)
    end
    return places
		
  end
	
	def self.find_ids_by_country_code country_code

		coll=self.collection.aggregate([

		{:$match=>{:$and=> [{'address_components.types'=>'country'},{'address_components.short_name' =>country_code}]}},

		{:$project=>{'address_components._id':1}}])

		coll.map {|doc| doc[:_id].to_s}

	end
	
	def self.get_country_names
		pipe=[]
		pipe << {'$project': {'address_components.long_name': 1, 'address_components.types': 1}}
		pipe << {'$unwind': '$address_components'}
		pipe << {'$match' => {'address_components.types' => 'country'}}
		pipe << {'$group' => {:_id=>"$address_components.long_name"}}
	
    return collection.aggregate(pipe).to_a.map{|a| a[:_id]}
	end
	
	def self.get_address_components(sort=nil, offset=nil, limit=nil)
		pipe=[]
		pipe << {:$project=>{:address_components=>1, :formatted_address=>1, "geometry.geolocation":1}}
		pipe << {:$unwind=>'$address_components'}
		pipe << {:$sort=>sort} if !sort.nil?
		pipe << {:$skip=>offset} if !offset.nil?
		pipe << {:$limit=>limit} if !limit.nil?
		result = self.collection.aggregate(pipe)
  end
	
	
	def photos(offset=0, limit=0)
		searchID = BSON::ObjectId.from_string(@id)
		result = Photo.mongo_client.database.fs.find({"metadata.place"=>searchID}).skip(offset)
		
		result = limit.nil? ? result.to_a : result.limit(limit).to_a
		photos = []
    result.each do |r|
      photos << Photo.new(r)
    end
		return photos
	end
	

	
 def destroy
    self.class.collection
              .find(:_id=>BSON::ObjectId.from_string(@id))
              .delete_one   
  end
	
	def self.find id
    result = if id.instance_of?(BSON::ObjectId)
      collection.find(:_id=> id).first
    else
      collection.find(:_id=> BSON::ObjectId.from_string(id)).first
    end
    return result.nil? ? nil : Place.new(result)
  end
	
	def self.to_places(input)  	
		place_objects = []  	
		input.each { |p| place_objects << Place.new(p) }  	
		return place_objects
	end
	
	def self.mongo_client
   Mongoid::Clients.default
  end
	
	def self.load_all(f)		
	
		places=JSON.parse(f.read)
		
		self.collection.insert_many(places)	
	end

	def place
		!@place.nil? ? Place.find(@place.id) : nil
	end
	
	def initialize(params={})
    @id = params[:_id].to_s
    @formatted_address = params[:formatted_address]
		
		unless params[:geometry][:geolocation].nil?
    	@location = Point.new(params[:geometry][:geolocation])
		end
		
		unless params[:address_components].nil?
    	@address_components = params[:address_components].map {|a| AddressComponent.new(a)}
		end
	
  end
end



