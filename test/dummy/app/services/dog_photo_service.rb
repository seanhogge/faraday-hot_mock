class DogPhotoService
  def initialize
  end

  def conn
    @conn = Faraday.new(url: "https://dog.ceo/api/") do |faraday|
      faraday.request :json
      faraday.response :json
      faraday.response :raise_error
      faraday.request :hot_mock
    end
  end
end
