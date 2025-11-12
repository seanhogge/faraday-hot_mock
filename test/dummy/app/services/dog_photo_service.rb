class DogPhotoService
  def initialize
  end

  def conn
    @conn = Faraday.new(url: "https://dog.ceo/api/") do |faraday|
      faraday.request :json
      faraday.response :json
      faraday.adapter :hot_mock
    end
  end
end
