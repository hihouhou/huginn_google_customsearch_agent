module Agents
  class GoogleCustomsearchAgent < Agent
    include FormConfigurable
    can_dry_run!
    no_bulk_receive!
    default_schedule 'every_1h'

    description do
      <<-MD
      The Google Custom search Agent uses customsearch.googleapis.com and creates an event for new result.

      `query` is for the wanted query.

      `searchengine` is for the searchengine used with the query (https://programmablesearchengine.google.com/cse/all).

      `debug` is used to verbose mode.

      `token` is needed for the api (go to https://console.cloud.google.com/apis/credentials/key).

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.
      MD
    end

    event_description <<-MD
      Events look like this:

          {
            "kind": "customsearch#search",
            "url": {
              "type": "application/json",
              "template": "https://www.googleapis.com/customsearch/v1?q={searchTerms}&num={count?}&start={startIndex?}&lr={language?}&safe={safe?}&cx={cx?}&sort={sort?}&filter={filter?}&gl={gl?}&cr={cr?}&googlehost={googleHost?}&c2coff={disableCnTwTranslation?}&hq={hq?}&hl={hl?}&siteSearch={siteSearch?}&siteSearchFilter={siteSearchFilter?}&exactTerms={exactTerms?}&excludeTerms={excludeTerms?}&linkSite={linkSite?}&orTerms={orTerms?}&relatedSite={relatedSite?}&dateRestrict={dateRestrict?}&lowRange={lowRange?}&highRange={highRange?}&searchType={searchType}&fileType={fileType?}&rights={rights?}&imgSize={imgSize?}&imgType={imgType?}&imgColorType={imgColorType?}&imgDominantColor={imgDominantColor?}&alt=json"
            },
            "queries": {
              "request": [
                {
                  "title": "Google Custom Search - XXXXXXXX",
                  "totalResults": "6",
                  "searchTerms": "XXXXXXXX",
                  "count": 6,
                  "startIndex": 1,
                  "inputEncoding": "utf8",
                  "outputEncoding": "utf8",
                  "safe": "off",
                  "cx": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
                }
              ]
            },
            "context": {
              "title": "XXXXXX"
            },
            "searchInformation": {
              "searchTime": 0.373951,
              "formattedSearchTime": "0.37",
              "totalResults": "6",
              "formattedTotalResults": "6"
            },
            "spelling": {
              "correctedQuery": "XXXXXXXX",
              "htmlCorrectedQuery": "<b><i>XXXXXXXX</i></b>"
            },
            "items": [
              {
                "kind": "customsearch#result",
                "title": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
                "htmlTitle": "XXXXXXXXXXXXXXXXXXXXXXXX</b> - XXXXXX",
                "link": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
                "displayLink": "XXXXXXXXXXXXXX",
                "snippet": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
                "htmlSnippet": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
                "cacheId": "XXXXXXXXXXXX",
                "formattedUrl": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
                "htmlFormattedUrl": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
              }
            ]
          }
    MD

    def default_options
      {
        'query' => '',
        'changes_only' => 'true',
        'token' => '',
        'searchengine' => '',
        'expected_receive_period_in_days' => '2',
        'debug' => 'false'
      }
    end

    form_configurable :query, type: :string
    form_configurable :changes_only, type: :boolean
    form_configurable :debug, type: :boolean
    form_configurable :token, type: :string
    form_configurable :searchengine, type: :string
    form_configurable :expected_receive_period_in_days, type: :string

    def validate_options
      if options.has_key?('changes_only') && boolify(options['changes_only']).nil?
        errors.add(:base, "if provided, changes_only must be true or false")
      end

      if options.has_key?('debug') && boolify(options['debug']).nil?
        errors.add(:base, "if provided, debug must be true or false")
      end

      unless options['token'].present?
        errors.add(:base, "token is a required field")
      end

      unless options['searchengine'].present?
        errors.add(:base, "searchengine is a required field")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end

    end

    def working?
      event_created_within?(options['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def check
      fetch
    end

    private

    def fetch
      url = "https://www.googleapis.com/customsearch/v1?q=" + interpolated['query'] + "&key=" + interpolated['token'] + "&cx=" + interpolated['searchengine']

      uri = URI.parse(url)
      response = Net::HTTP.get_response(uri)
      
      log "request  status : #{response.code}"

      payload = JSON.parse(response.body)
      base = JSON.parse(response.body)

      if interpolated['debug'] == 'true'
        log url
        log payload
      end

      if interpolated['changes_only'] == 'true'
        if payload.to_s != memory['last_status']
          if payload['items']
            if "#{memory['last_status']}" == ''
              payload['items'].each do |item|
                base['items'] = item
                create_event payload: base
              end
            else
              last_status = memory['last_status'].gsub("=>", ": ").gsub(": nil,", ": null,")
              last_status = JSON.parse(last_status)
              if !payload['items'].nil?
                if !payload['items'].empty?
                  payload['items'].each do |item|
                    found = false
                    if interpolated['debug'] == 'true'
                      log "found is #{found}!"
                      log item
                    end
                    if !last_status['items'].nil?
                      if !last_status['items'].empty?
                        last_status['items'].each do |itembis|
                          if item == itembis || item['link'] == itembis['link']
                            found = true
                          end
                          if interpolated['debug'] == 'true'
                            log "found is #{found}!"
                          end
                        end
                      end
                    end
                    if found == false
                      base['items'] = item
                      if interpolated['debug'] == 'true'
                        log "found is #{found}! so event created"
                        log item
                      end
                      create_event payload: base
                    end
                  end
                end
              end
            end
          end
          memory['last_status'] = payload.to_s
        end
      else
        create_event payload: payload
        if payload.to_s != memory['last_status']
          memory['last_status'] = payload.to_s
        end
      end
    end
  end
end
