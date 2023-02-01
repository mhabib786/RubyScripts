require "byebug"
require "mechanize"
require 'net/http'
require 'uri'
require 'nokogiri'
require 'csv'
require 'json'
class TrenitaliaScrapeApi

  def send_get_request(station_name)
    url = "https://www.lefrecce.it/Channels.Website.BFF.WEB/website/locations/search?name=#{station_name}&limit=10"
    puts url
    agent = Mechanize.new
    page = agent.get(url)
  end

	def main_request(arrival_id, departure_id, time_date)
		uri = URI.parse("https://www.lefrecce.it/Channels.Website.BFF.WEB/website/ticket/solutions")
		request = Net::HTTP::Post.new(uri)
		request.content_type = "application/json"
		request["Authority"] = "www.lefrecce.it"
		request["Accept"] = "application/json, application/pdf, text/calendar"
		request["Accept-Language"] = "en-GB"
		request["Callertimestamp"] = "1665589371960"
		request["Channel"] = "41"
		request["Origin"] = "https://www.lefrecce.it"
		request["Referer"] = "https://www.lefrecce.it/Channels.Website.WEB/"
		request["Sec-Ch-Ua"] = "\"Chromium\";v=\"106\", \"Google Chrome\";v=\"106\", \"Not;A=Brand\";v=\"99\""
		request["Sec-Ch-Ua-Mobile"] = "?0"
		request["Sec-Ch-Ua-Platform"] = "\"Linux\""
		request["Sec-Fetch-Dest"] = "empty"
		request["Sec-Fetch-Mode"] = "cors"
		request["Sec-Fetch-Site"] = "same-origin"
		request["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36"
		request["Whitelabel_referrer"] = "www.lefrecce.it"
		request["X-Requested-With"] = "Fetch"
		request.body = JSON.dump({
				"departureLocationId" => departure_id,
				"arrivalLocationId" => arrival_id,
				"departureTime" => time_date,
				"adults" => 1,
				"children" => 0,
				"criteria" => {
					"frecceOnly" => false,
					"regionalOnly" => false,
					"noChanges" => false,
					"order" => "DEPARTURE_DATE",
					"offset" => 0,
					"limit" => 10
				},
				"advancedSearchRequest" => {
						"bestFare" => false
				}
		})

		req_options = {
				use_ssl: uri.scheme == "https",
		}
		# response = Net::HTTP::Proxy(proxyrack_host,  proxyrack_random_port,proxyrack_username,proxyrack_password).start(uri.hostname, uri.port, req_options) do |http|
		response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
			http.request(request)
		end
	end

  def call
		station_one = "Milano Centrale"
		station_two = "Paris"
		date = "2023-02-18"
    page_one = send_get_request(station_one)
    page_two = send_get_request(station_two)
    id_one = JSON.parse(page_one.body)[0]["id"]
        id_two = JSON.parse(page_two.body)[0]["id"] 
    date_time = date+"T"+"00:00:00.000+05:00"
    main_page = main_request(id_one, id_two, date_time)
    if (main_page.code!="200")
			puts "request get failed"
		end  
    parsing(main_page)
  end

	def parsing(page)
		json = JSON.parse(page.body)
			data_array = []
			json["solutions"].each do|data|
				data_hash = {}  
				first_class_price = 0
				first_c_price,second_c_price = 0,0
				first_price_index =  data["grids"][0]["services"].map{|e| e["offers"][0]["serviceName"]=="PREMIUM" || e["offers"][0]["serviceName"]=="1ª CLASSE"}.find_index(true) rescue nil
				second_price_index =  data["grids"][0]["services"].map{|e| e["offers"][0]["serviceName"]=="STANDARD" || e["offers"][0]["serviceName"]=="2ª CLASSE"}.find_index(true) rescue nil
				first_c_price =  data["grids"][0]["services"][first_price_index]["offers"][0]["price"]["amount"] rescue nil
				second_c_price = data["grids"][0]["services"][second_price_index]["offers"][0]["price"]["amount"] rescue nil
				first_c_price = 0 if first_c_price.nil?
				second_c_price = 0 if second_c_price.nil?
				solution_id = data["solution"]["id"]
				train_numbers = data["solution"]["trains"][0]["trainCategory"] +" "+ data["solution"]["trains"][0]["name"]
				train_count = data["solution"]["trains"].count
				layover = nil if train_count==1
				operator = "TRENITALIA "
				changes = 0
				if train_count >1
					train_numbers = data["solution"]["trains"].map{|e| e["trainCategory"] +" "+ e["name"]}.join(",")
					connections = data["solution"]["nodes"].map{|e| e["destination"]}[0..-2].join(",")
					departure_connections = data["solution"]["nodes"].map{|e| e["departureTime"].split(".").first.gsub("T"," ")}[1..-1]
					arrival_connections =  data["solution"]["nodes"].map{|e| e["arrivalTime"].split(".").first.gsub("T"," ")}[0..-2]
					layover_connections = parse_time(departure_connections, arrival_connections)
					departure_connections = departure_connections.map{|e| e.split(" ").last.split(":")[0..-2].join(":")}.join(",")
					arrival_connections = arrival_connections.map{|e| e.split(" ").last.split(":")[0..-2].join(":")}.join(",")
					changes = train_count - 1
					operator = (operator * train_count)&.split(" ")&.join(",")
				end
				if changes == 0
					layover_connections = "NULL"
					departure_connections = "NULL"
					arrival_connections = "NULL"
					connections = "NULL"
				end
				departure_time =  data["solution"]["departureTime"].split(".").first.split("T").last
				arrival_time = data["solution"]["arrivalTime"].split(".").first.split("T").last
				data_hash = {
					:origin_station => data["solution"]["origin"],
					:destin_station => data["solution"]["destination"],
					:departure_date => data["solution"]["departureTime"].split("T").first,
					:arrival_date => data["solution"]["arrivalTime"].split("T").first,
					:departure_time => departure_time.split(":")[0..-2].join(":"),
					:duration       => cnvrt_duration_to_integer(data["solution"]["duration"]),
					:arrival_time   => arrival_time.split(":")[0..-2].join(":"),
					:oneway         => @oneway,
					:direction      => @direction,
					:changes        => changes,
					:train_numbers  => train_numbers,
					:operator       => operator,
					:layover_connections => layover_connections,
					:connections => connections,
					:departure_connections => departure_connections,
					:arrival_connections => arrival_connections,
					:price => {
						:first_class  => first_c_price,
						:second_class => second_c_price
					}
				}
				data_array << data_hash
			end
			puts data_array
	end

	def parse_time(departure_time, arrival_time)
		time_array = []
		departure_time.each_with_index do |deptime, index|      
			dtime = DateTime.strptime(deptime, '%Y-%m-%d %H:%M:%S').to_time
			atime = DateTime.strptime(arrival_time[index], '%Y-%m-%d %H:%M:%S').to_time
			data = dtime - atime
			time = nil
			if data.to_i > 3600
				time = Time.at(data).utc.strftime("%kh%Mm")
			elsif data.to_i == 3600
				time = Time.at(data).utc.strftime("%kh")
			else
				time = Time.at(data).utc.strftime("%Mm")
			end
			time_array << time
		end
		time_array.join(',')
	end

	def cnvrt_duration_to_integer str
		str.slice! "\'"
		str.gsub!(/[[:space:]]/, "")
		delimiters = ["gg", "h"]
		strs = str.split(Regexp.union(delimiters))
		duration = 0
		if (strs.length == 3)
			duration = strs[0].to_i * 24 * 60 + strs[1].to_i * 60 + strs[2].to_i
		elsif (strs.length == 2)
			duration = strs[0].to_i * 60 + strs[1].to_i
		elsif (strs.length == 1)
			duration = strs[0].to_i
		end
		duration
	end

end
TrenitaliaScrapeApi.new.call