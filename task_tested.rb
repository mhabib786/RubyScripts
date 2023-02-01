require "byebug"
require "mechanize"
require 'net/http'
require 'uri'
require 'nokogiri'
require 'csv'
require 'json'

class TaskSeven

  def request(page, id)
    uri = URI.parse("https://www.tcdb.com/Checklist.cfm/sid/72970?PageIndex=#{page}&MultiID=#{id}")
    request = Net::HTTP::Get.new(uri)
    request["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9"
    request["Accept-Language"] = "en-US,en;q=0.9,ur;q=0.8"
    request["Connection"] = "keep-alive"
    request["Referer"] = "https://www.tcdb.com/Checklist.cfm/sid/72970?PageIndex=#{page-1}&MultiID=#{id}"
    request["Sec-Fetch-Dest"] = "document"
    request["Sec-Fetch-Mode"] = "navigate"
    request["Sec-Fetch-Site"] = "same-origin"
    request["Sec-Fetch-User"] = "?1"
    request["Upgrade-Insecure-Requests"] = "1"
    request["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36"
    request["Sec-Ch-Ua"] = "\"Chromium\";v=\"106\", \"Google Chrome\";v=\"106\", \"Not;A=Brand\";v=\"99\""
    request["Sec-Ch-Ua-Mobile"] = "?0"
    request["Sec-Ch-Ua-Platform"] = "\"Linux\""

    req_options = {
      use_ssl: uri.scheme == "https",
    }

    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(request)
    end
  end

  def main (url, flag =0)
    if flag==0
      data_hash = {}
      data_hash[:product_name] = nil
      data_hash[:year] = nil
      data_hash[:series] = nil
      data_hash[:tcdb_set_id] = nil
      data_hash[:tcdb_card_id] = nil
      data_hash[:card_number] = nil
      data_hash[:subject_name] = nil
      data_hash[:subject_group] = nil
      data_hash[:tcdb_subject_id] = nil
      data_hash[:tcdb_subject_group_id] = nil
      data_hash[:tcdb_checklist_url] = nil
      data_hash[:front_image] = nil
      data_hash[:back_image] = nil
      data_hash[:uer] = nil
      data_hash[:error_text_field] = nil
      data_hash[:rc] = nil
      data_hash[:variation] = nil
      data_hash[:print_serial] = nil
      data_hash[:print_run] = nil
      data_hash[:issued_auto] = nil
      data_hash[:supplemental_title_field] = nil
      CSV.open("tcdb_card.csv", "a") do |csv|
        csv << data_hash.keys
      end
    end
    @agent = Mechanize.new
    page = @agent.get(url)
    pagination="?PageIndex=1"
    multi_set = page.css(".alert-info option")[1..].map{|e| e.values} rescue []
    if !multi_set.empty? && flag==0
      multi_set.flatten.reject{|e| e=="selected"}.map{|e| main("https://www.tcdb.com"+e,1)}
      return 
    end
    @card_count = page.css("#content p")[1].text.split(":").last.strip.to_i rescue ''
    @parent_set_id = url.split("/")[-2].to_i
    new_page = @agent.get("https://www.tcdb.com" + page.css(".d-md-block").first.css("a")[-4]["href"])
    @glossary = new_page.css(".block1 tr")[1..].map{|e| e.css("td").map{|e| e.text}.join(":")}.join(",") rescue ""
    insert_page  = @agent.get("https://www.tcdb.com" + page.css(".d-md-block").first.css("a")[5]["href"])
    all_links = insert_page.css(".block1 table").last.css("tr").map{|e| "https://www.tcdb.com" + e.css("td a")[0]["href"]}
    if url.include?"Multi"
      insert_page_parsing(url.gsub("?",pagination+"&"), nil, 1)
    else
      insert_page_parsing(url+pagination, nil, 1) 
    end
  end
  
  def insert_page_parsing url, response, page_number    
    page = @agent.get(url) if response.nil?
    page = Nokogiri::HTML(response.body) unless response.nil?
    last_page = page.css(".pagination").first.css("li").map{|e| e.css("a").text.to_i}.reject{|e| e==0}.last rescue -1
    last_page = page_number if last_page==0
    page.css(".col-md-6 .block1 table").last.css("tr").each do|tr|
      year = page.css(".breadcrumb-item")[-2].text
      product_name = page.css("p strong").first.text.split("Series").first.gsub(year,"").strip
      series = page.css("p strong").first.text.split("Series").last.strip.to_i rescue ""
      data = tr.css('td[valign="top"]').map{|e| e.text.strip}.reject{|e| e.empty?}.map{|e| e.gsub(" / ",",")}
      description = tr.css('.figure-caption').text rescue nil
      uer, rc, au = false
      text, pr  = ""
      variation = []
      v = 0
      new_description = ""
      if(description.include?"UER")
        uer = true
        uer_index = description.gsub("; ",":").split(":").map{|e| e=="UER"}.find_index(true)
        text = description.split(":")[uer_index+1] rescue ""
        text = description.split(":")[uer_index] rescue "" if text.nil?

        new_description = description.gsub("UER:"+text,"") rescue nil
      elsif(description.include?"VAR")
        variation[v] = description.split(":").last.strip.gsub(";","").gsub(" / ",",")  
        new_description = description.gsub("VAR:"+variation[v],"") rescue nil
      elsif(description.include?"ERR") 
        variation[v] = description.split(":").last.strip.gsub(";","").gsub(" / ",",") 
        new_description = description.gsub("ERR:"+variation[v],"") rescue nil
      elsif(description.include?"COR") 
        variation[v] = description.split(":").last.strip.gsub(";","").gsub(" / ",",")
        description = description.gsub("COR:"+variation[v],"") rescue nil
      elsif(description.include?"PR") 
        pr = description.split(":").last.strip rescue nil
        new_description = description.gsub("PR:"+variation[v],"") rescue nil
      end
      if data.count==1 
        data = tr.css('td').map{|e| e.text.strip}.select{|e| e.include?"/"}.map{|e| e.gsub(" / ",",")} 
      end
      check = tr.css('td').map{|e| e.text.strip}.reject{|e| e.empty?}[3].split.last rescue nil
      link = "https://www.tcdb.com" + tr.css('td a')[3]["href"]
      image_page = @agent.get(link)
      front_check = image_page.css(".row .col-sm-6").first.css("img")[0]["src"].include?"gif" rescue true
      back_check = image_page.css(".row .col-sm-6").last.css("img")[0]["src"].include?"gif" rescue true
      front_image = "https://www.tcdb.com" + image_page.css(".row .col-sm-6").first.css("img")[0]["src"]  rescue nil  unless front_check
      back_image = "https://www.tcdb.com" + image_page.css(".row .col-sm-6").last.css("img")[0]["src"] rescue nil unless back_check
      data_hash = {}
      glossary_items = @glossary.split(",").map{|e| e.split(":").first}
      field_text = tr.css(".figure-caption").text rescue "*"
      all_tags = data[1].gsub(", "," ").gsub(field_text,"").gsub(":","").gsub(";","").split rescue []
      tags = glossary_items.intersection(all_tags)
      title_field = []
      unless tags.nil?
        k = 0
        tags.each do|i|
          if(i=="UER")
            uer = true
          elsif(i=="RC")
            rc = true
          elsif(i=="AU")
            au = true
          elsif(i=="SSS")
            title_field[k] = field_text
            k =+1
            title_field[k] = @glossary.split(",").map{|e|  e.split(":").last if e.split(":").first==i}.reject{|e| e.nil?}[0]
            k =+1
          elsif(i.include?"SN")
            next
          else
            title_field[k] = @glossary.split(",").map{|e|  e.split(":").last if e.split(":").first==i}.reject{|e| e.nil?}[0]
            k =+1
          end
        end
      end   
      sn = check.split("SN").last if check.include?"SN"
      if url.include?"Multi"
        sid = url.split("/").last.split("?").first.to_i
      else
        sid = url.split("/")[-2].strip.to_i
      end
      name = ''
      description=description.gsub(" / ",",") if description.include?"/"
      name_index = data[1].gsub(",",'').split.map{|e| e.include?tags[0]}.find_index(true) rescue ""
      name = data[1].split[0...name_index].join(" ") rescue nil
      name = name.gsub(field_text,"") rescue nil
      name = name.gsub(variation.first,"") rescue nil unless variation.empty?
      name=(data[1].gsub(field_text.gsub("/ ",","),"").split(" ")-tags).join(" ") rescue nil if name.nil?
      name = name.gsub(variation.first,"") rescue nil unless variation.empty?
      if pr.nil?
        pr_index = all_tags.map{|e| e.include?"PR"}.find_index(true) rescue "0"
        pr=all_tags[pr_index..].join(" ").scan(/\d/).join.to_i rescue nil unless pr_index.nil?
        title_field[k] = all_tags[pr_index..].join(" ").gsub("PR#{pr}","") rescue "" unless pr.nil? || pr==0
        name = name.gsub(all_tags[pr_index..].join(" "),"").strip unless pr.nil? || pr==0
      end
      sid = url.gsub("?","/").split("/")[-2].strip.to_i if sid == 0
      data_hash[:product_name] = product_name
      data_hash[:year] = year
      data_hash[:series] = series
      data_hash[:tcdb_set_id] = sid
      data_hash[:tcdb_card_id] = link.split("/")[7]
      data_hash[:card_number] = data[0].split(",").map{|e| e.gsub(/[a-z]/,"")}.join(",")
      data_hash[:card_number] =  "NO_NUMBER" if data_hash[:card_number] == "NNO"
      if(name.start_with?("Checklist"))
        v=+1
        variation[v] = name.split(":").last
      end
      data_hash[:subject_name] =  name.gsub("; "," ").gsub(variation.map{|e| e.gsub(",","")}.join,"").gsub(description.gsub(":","").split.select{|e| e.length==3}.first,"").gsub(text.strip.gsub(","," "),"").gsub("; "," ").gsub(": "," ").strip rescue nil unless (variation.empty?) && (text.empty?) 
      data_hash[:subject_name] = name rescue nil if variation.empty? && text.empty?
      data_hash[:subject_group] = data[2]
      data_hash[:tcdb_subject_id] = tr.css('td  a')[4]["href"].split("/")[-2].strip.to_i rescue nil
      data_hash[:tcdb_subject_group_id] = tr.css('td a')[5]["href"].split("/")[-2].strip.to_i rescue nil
      data_hash[:tcdb_subject_id] = tr.css('td  a')[3]["href"].split("/")[-2].strip.to_i rescue nil if tr.css('td  a').count==5
      data_hash[:tcdb_subject_group_id] = tr.css('td a')[4]["href"].split("/")[-2].strip.to_i rescue nil if tr.css('td  a').count==5
      data_hash[:tcdb_subject_id] = nil if data_hash[:tcdb_subject_id]==0
      data_hash[:tcdb_checklist_url] = url
      data_hash[:front_image] = front_image
      data_hash[:back_image] = back_image
      data_hash[:uer] = uer rescue nil
      data_hash[:error_text_field] = text rescue nil
      data_hash[:rc] = rc rescue nil
      data_hash[:variation] = variation.join(",") rescue nil
      data_hash[:print_serial] = sn rescue nil
      data_hash[:print_run] = pr rescue nil 
      data_hash[:pr_index] = nil if pr==0
      data_hash[:issued_auto] = au rescue nil
      data_hash[:supplemental_title_field] = title_field.join(",") rescue nil
      CSV.open("tcdb_card.csv", "a") do |csv|
        csv << data_hash.values
      end
    end
    puts url
    if (url.include?"MultiID")
      page = url.split("MultiID").first.split("=").last.to_i
      return if last_page == page  || last_page == -1
      puts "page==#{page+1}"
      new_url = url.gsub("Index="+(page).to_s,"Index="+(page+1).to_s)
      insert_page_parsing(new_url,request(page+1, url.split("=").last.to_i), last_page)
    else      
      puts url.split("=").last.to_i
      if (last_page == url.split("=").last.to_i) || (last_page == -1)
      return nil
      end
      insert_page_parsing(url.gsub("=#{url.split("=").last.to_i}","=#{url.split("=").last.to_i+1}"), nil, last_page) unless url.include?"Multi"
    end
  end


  url = "https://www.tcdb.com/Checklist.cfm/sid/72970/1985-Topps-Garbage-Pail-Kids-Series-1"
  TaskSeven.new.main(url)
end