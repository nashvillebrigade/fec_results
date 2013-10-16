require 'rubygems'
require 'remote_table'

module FecResults
  class Congress

    def initialize(params={})
      params.each_pair do |k,v|
       instance_variable_set("@#{k}", v)
      end
    end

    # given a year and an optional chamber ('house' or 'senate') and state ('ar', 'az', etc.) 
    # retrieves election results that fit the criteria
    def process(year, options={})
      send("process_#{year.to_s}(#{options})")
    end

    def process_2012(options={})
      results = []
      url = FecResults::CONGRESS_URLS['2012']
      t = RemoteTable.new(url, :sheet => "2012 US House & Senate Resuts")
      rows = t.entries
      rows.each do |candidate|
        c = {:year => 2012}
        next if candidate['CANDIDATE NAME (Last)'].blank?
        next if candidate['D'].blank?
        # find the office_type
        if candidate['FEC ID#'].first != 'n'
          c[:chamber] = candidate['FEC ID#'].first
        elsif candidate['D'].first == 'S'
          c[:chamber] = "S"
        else
          c[:chamber] = 'H'
        end
        c[:state] = candidate['STATE ABBREVIATION']
        c[:district] = candidate['D']
        c[:party] = candidate['PARTY']
        c[:incumbent] = candidate['(I)'] == '(I)' ? true : false
        c[:fec_id] = candidate['FEC ID#']
        c[:candidate_first] = candidate['CANDIDATE NAME (First)']
        c[:candidate_last] = candidate['CANDIDATE NAME (Last)']
        c[:candidate_name] = candidate['CANDIDATE NAME']

        c = update_vote_tallies(c, candidate)
        c = update_general_runoff(c, candidate) if c[:state] == 'LA'
        c = update_combined_totals(c, candidate) if ['CT', 'NY', 'SC'].include?(c[:state])

        c[:general_winner] = candidate['GE WINNER INDICATOR'] == "W" ? true : false unless c[:general_pct].nil?

        results << c
      end
      results = results.select{|r| r[:chamber] == options[:chamber]} if options[:chamber]
      results = results.select{|r| r[:state] == options[:state]} if options[:state]
      Result.create_congress(results)
    end

    def update_vote_tallies(c, candidate)
      if candidate['PRIMARY VOTES'] == 'Unopposed'
        c[:primary_unopposed] = true
        c[:primary_votes] = nil
        c[:primary_pct] = 100.0
      else
        c[:primary_unopposed] = false
        c[:primary_votes] = candidate['PRIMARY VOTES'].to_i
        c[:primary_pct] = candidate['PRIMARY %'].to_f*100.0
      end

      if candidate['RUNOFF VOTES'].blank?
        c[:runoff_votes] = nil
        c[:runoff_pct] = nil
      else
        c[:runoff_votes] = candidate['RUNOFF VOTES'].to_i
        c[:runoff_pct] = candidate['RUNOFF %'].to_f*100.0
      end

      if candidate['GENERAL VOTES '] == 'Unopposed'
        c[:general_unopposed] = true
        c[:general_votes] = nil
        c[:general_pct] = 100.0
      elsif candidate['GENERAL VOTES '].blank?
        c[:general_unopposed] = false
        c[:general_votes] = nil
        c[:general_pct] = nil
      else
        c[:general_unopposed] = false
        c[:general_votes] = candidate['GENERAL VOTES '].to_i
        c[:general_pct] = candidate['GENERAL %'].to_f*100.0
      end
      c
    end

    def update_general_runoff(c, candidate)
      unless candidate['GE RUNOFF ELECTION VOTES (LA)'].blank?
        c[:general_runoff_votes] = candidate['GE RUNOFF ELECTION VOTES (LA)'].to_i
        c[:general_runoff_pct] = candidate['GE RUNOFF ELECTION % (LA)'].to_f*100.0
      end
      c
    end

    def update_combined_totals(c, candidate)
      unless candidate['COMBINED GE PARTY TOTALS (CT, NY, SC)'].blank?
        c[:general_combined_party_votes] = candidate['COMBINED GE PARTY TOTALS (CT, NY, SC)'].to_i
        c[:general_combined_party_pct] = candidate['COMBINED % (CT, NY, SC)'].to_f*100.0
      end
      c
    end

  end
end