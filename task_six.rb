require "byebug"
require "mechanize"
require 'net/http'
require 'uri'
require 'nokogiri'
require 'csv'
require 'json'

class TaskSix

  def main
    data_hash = {}
    data_hash[:tcdb_card_count] = nil
    data_hash[:tcdb_set_id] = nil
    data_hash[:tcdb_checklist_url] = nil
    data_hash[:parent_set_name] = nil
    data_hash[:card_set_name] = nil
    data_hash[:category] = nil
    data_hash[:tcdb_parent_set_id] = nil
    data_hash[:tcdb_glossary] = nil
    data_hash[:tcdb_notes] = nil
    CSV.open("tcdb_data.csv", "a") do |csv|
      csv << data_hash.keys
    end
    @agent = Mechanize.new
    url="https://www.tcdb.com/ViewAll.cfm/sp/Baseball?MODE=Years"
    page = @agent.get(url)
    year_urls = page.css("td a").map{|e|  "https://www.tcdb.com"+e["href"]}.sort
    year_urls[2..].map{|year|  year_parsing(year)}
  end

  def year_parsing url
    year_page = @agent.get(url)
    puts url
    year_page.css(".block1 ul")[0..1].each do |list|
      list.css("li").map{|e| inner_page("https://www.tcdb.com"+e.css("a")[0]["href"])}
    end
  end

  def inner_page url
    puts url
    inner_page = @agent.get(url)
    tcdb_card_count = inner_page.css(".row .col-sm-8 p")[0].text.split(":").last.strip.to_i rescue ''
    tcdb_set_id = inner_page.css(".more").first.css("a")[0]["href"].split("/")[3].to_i
    @tcdb_parent_set_id = inner_page.css(".more").first.css("a")[0]["href"].split("/")[3].to_i
    tcdb_checklist_url = "https://www.tcdb.com" + inner_page.css(".more").first.css("a")[0]["href"]
    glossary_url = "https://www.tcdb.com" + inner_page.css(".more").first.css("a")[-4]["href"]
    insert_page_url = "https://www.tcdb.com" + inner_page.css(".more").first.css("a")[5]["href"]
    check_list_page =@agent.get(tcdb_checklist_url)
    set_urls = check_list_page.css(".form-select").last.css("option").map{|e| e.values}[2..].flatten.map{|e| "https://www.tcdb.com"+e} rescue nil
    # set_urls.map{|e| last_page(e)} unless set_urls.nil?
    checked = check_list_page.css(".col-md-3 .block1")[1].text.strip.split("\n").first.strip rescue nil
    if checked =="Notes"
      tcdb_notes = check_list_page.css(".col-md-3 .block1")[1].text.strip.split("\n").last rescue ""
    end
    glossary_page = @agent.get(glossary_url)
    tcdb_glossary = glossary_page.css(".block1 tr")[1..].map{|e| e.css("td").map{|e| e.text}.join(":")}.join(",") rescue ""
    insert_page = @agent.get(insert_page_url)
    @parent_set_name = insert_page.css(".col-md-6 h1").text
    @category = insert_page.css(".breadcrumb li")[1].text
    last_page_url = "https://www.tcdb.com" + insert_page.css(".block1 table")[-1].css("a")[0]["href"] rescue nil
    data_hash = {}
    data_hash[:tcdb_card_count] = tcdb_card_count
    data_hash[:tcdb_set_id] = tcdb_set_id
    data_hash[:tcdb_checklist_url] = tcdb_checklist_url
    data_hash[:parent_set_name] = @parent_set_name
    data_hash[:card_set_name] = @parent_set_name
    data_hash[:category] = @category
    data_hash[:tcdb_parent_set_id] = @tcdb_parent_set_id
    data_hash[:tcdb_glossary] = tcdb_glossary
    data_hash[:tcdb_notes] = tcdb_notes
    
    CSV.open("tcdb_data.csv", "a") do |csv|
      csv << data_hash.values
    end
    last_page(last_page_url) unless last_page_url.nil?
  end


  def last_page url
    
    set_page = @agent.get(url)
    glossary_set_page = @agent.get("https://www.tcdb.com"+set_page.css(".d-md-none")[1].css("p a")[-4]["href"])
    data_hash = {}
    data_hash[:tcdb_card_count] = set_page.css(".nopadding .block1").first.css("p")[1].text.split.last.to_i
    data_hash[:tcdb_set_id] = url.split("/")[5].to_i
    data_hash[:tcdb_checklist_url] = url
    data_hash[:parent_set_name] = @parent_set_name
    data_hash[:card_set_name] = set_page.css(".nopadding .block1").first.css("p")[0].text
    data_hash[:category] = @category
    data_hash[:tcdb_parent_set_id] = @tcdb_parent_set_id
    data_hash[:tcdb_glossary] = glossary_set_page&.css(".block1 tr")[1..].map{|e| e.css("td").map{|e| e.text}.join(":")}.join(",") rescue ""
    data_hash[:tcdb_notes] = set_page.css(".col-md-3 .block1")[1].text.strip.split("\n").last if set_page.css(".col-md-3 .block1")[1].text.strip.split("\n").first.strip=="Notes"
    CSV.open("tcdb_data.csv", "a") do |csv|
      csv << data_hash.values
    end

  end

  
  TaskSix.new.main
end