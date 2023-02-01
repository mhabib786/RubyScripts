require "byebug"
require "mechanize"
require 'net/http'
require 'uri'
require 'nokogiri'
require 'csv'
require 'json'
class TaskFour
	
	def request (page)
    uri = URI.parse("https://b1dnt5ruef-dsn.algolia.net/1/indexes/production_universal_search/query")
    request = Net::HTTP::Post.new(uri)
    request.content_type = "text/plain;charset=UTF-8"
    request["Accept"] = "*/*"
    request["Accept-Language"] = "en-US,en;q=0.9,ur;q=0.8"
    request["Cache-Control"] = "max-age=0"
    request["Connection"] = "keep-alive"
    request["Origin"] = "https://app.alt.xyz"
    request["Referer"] = "https://app.alt.xyz/"
    request["Sec-Fetch-Dest"] = "empty"
    request["Sec-Fetch-Mode"] = "cors"
    request["Sec-Fetch-Site"] = "cross-site"
    request["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36"
    request["Sec-Ch-Ua"] = "\"Chromium\";v=\"106\", \"Google Chrome\";v=\"106\", \"Not;A=Brand\";v=\"99\""
    request["Sec-Ch-Ua-Mobile"] = "?0"
    request["Sec-Ch-Ua-Platform"] = "\"Linux\""
    request["X-Algolia-Api-Key"] = "c128227440debf3ee6434c213d218e58"
    request["X-Algolia-Application-Id"] = "B1DNT5RUEF"
    request.body = JSON.dump({
      "facetFilters" => [
        [
          "listingType:AUCTION"
        ]
      ],
      "hitsPerPage" => 24,
      "page" => page,
      "filters" => "showResult:true",
      "numericFilters" => "",
      "clickAnalytics" => true
    })

    req_options = {
      use_ssl: uri.scheme == "https",
    }

    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(request)
    end
	end
	
	def main
    data_hash = {}
    data_hash[:source_provider] = nil
    data_hash[:source_title] = nil
    data_hash[:source_url] = nil
    data_hash[:magic_type] =  nil
    data_hash[:magic_rarity] = nil
    data_hash[:price] = nil
    data_hash[:quantity] = nil
    data_hash[:image_urls] =  nil
    CSV.open("card_data.csv", "a") do |csv|
      csv << data_hash.keys
    end
    @agent = Mechanize.new
    urls =["https://www.cardkingdom.com/catalog/search?filter[tab]=mtg_foil&filter%5Bname%5D=&search=header", "https://www.cardkingdom.com/catalog/search?filter%5Btab%5D=mtg_card&filter%5Bname%5D=&search=header"]
    urls.each do |url|
      page = @agent.get(url)
      total_pages = page.css("ul.pagination li")[-2].text.strip.to_i
      i = 1
      while(i < total_pages+1)
        url = "#{url}&page=#{i}"
        page = @agent.get(url)
        page.css(".mainListing div.productItemWrapper").each do |data|
          data_hash = {}
          foil = data.css("div.foil").text.capitalize rescue ""
          data_hash[:source_provider] = "card_kingdom"
          data_hash[:source_title] = data.css(".productDetailSet").text.split[0..-2].join(" ")+": "+data.css(".productDetailTitle a").text+" "+foil
          data_hash[:source_url] = "https://www.cardkingdom.com"+data.css(".mtg-card-static-wrapper").children[1].values[3] 
          data_hash[:magic_type] = data.css(".productDetailDrillIn").text.strip
          data_hash[:magic_rarity] = data.css(".productDetailSet").text.split[-2].gsub("(","").gsub(")","") 
          data_hash[:magic_rarity] = data.css(".productDetailSet").text.split.last.gsub("(","").gsub(")","") if foil.empty?
          data_hash[:price] = data.css(".addToCartWrapper .amtAndPrice .stylePrice")[1].text.strip
          data_hash[:quantity] = data.css(".styleQty").first.text.to_i
          data_hash[:image_urls] = data.css(".mtg-card-static-wrapper").children[1].values[-2]
          CSV.open("card_data.csv", "a") do |csv|
            csv << data_hash.values
          end
        end
        i+=1
      end
    end
 	end
   TaskFour.new.main
end


