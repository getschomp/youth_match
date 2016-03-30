require_relative './resource'
require 'active_support/hash_with_indifferent_access'

class ICIMS::Workflow < ICIMS::Resource

  attr_reader :id, :job_id, :person_id, :status

  def initialize(id: , job_id: , person_id: , status: )
    @id = id
    @job_id = job_id
    @person_id = person_id
    @status = status
  end

  def job
    @job ||= ICIMS::Job.find(@job_id)
  end

  def person
    @person ||= ICIMS::Person.find(@person_id)
  end

  # Move to ICIMS::Resource
  def save
    response = self.class.create(self.attributes.merge({id: nil}), return_instance: false)
    @id = self.class.get_id_from(response)
    true
  end

  def self.create(attributes, return_instance: true)
    payload = {
      baseprofile: attributes[:job_id],
      associatedprofile: attributes[:person_id],
      status: { id: attributes[:status] },
      source: "Other (Please Specify)",
      sourcename: 'org.mapc.youthjobs.lottery'
    }.to_json
    response = post '/applicantworkflows', { body: payload, headers: headers }
    if return_instance
      new(attributes.merge({ id: get_id_from(response) }))
    else
      response
    end
  end

  def update(status: nil)
    status = status || @status
    payload = { status: { id: status } }.to_json
    response = self.class.patch "/applicantworkflows/#{@id}", {
      body: payload, headers: self.class.headers
    }
    if response.response.code == "204"
      status
    else
      raise StandardError, "Invalid status #{response.response.code}, should have been 204"
    end
  end

  def accepted
    update(status: "C36951")
  end

  def declined
    update(status: "C14661")
  end

  def placed
    raise NotImplementedError, "no code for status yet"
    created(status: "TODO CODE NOT READY")
  end

  def self.find(id)
    response = get("/applicantworkflows/#{id}", headers: headers)
    handle response do |r|
      new(id: id, job_id: r['baseprofile']['id'], status: r['status']['id'],
        person_id: r['associatedprofile']['id'])
    end
  end

  def self.where(options={})
    response = post '/search/applicantworkflows',
      { body: build_filters(options).to_json, headers: headers }
    handle response do |r|
      Array(r['searchResults']).map { |res| find(res['id']) }
    end
  end

  def self.eligible(limit: nil)
    response = post '/search/applicantworkflows',
      { body: eligible_filter.to_json, headers: headers }
    handle response do |r|
      limit_results(r, limit).map { |res| find res['id'] }
    end
  end

  private

  def self.get_id_from(response)
    response.headers['location'].to_s.rpartition('/').last.to_i
  end

  def self.build_filters(options)
    filters = { filters: [], operator: '&' }
    filters[:filters] << person_filter(options) if options.include?(:person)
  end

  def self.person_filter(options)
    { name: 'applicantworkflow.person.id',
      value: [options[:person].to_s],
      operator: '=' }
  end

  def self.eligible_filter
    {
      filters: [
        {name: "applicantworkflow.customfield4006.text", value: [], operator: "="},
        {name: "applicantworkflow.customfield4007.text", value: [], operator: "="},
        {name: "applicantworkflow.customfield3300.text", value: ["135"], operator: "="},
        {
          name: "applicantworkflow.person.createddate",
          value: ["2013-03-25 4:00 AM"], # 4 AM since the time is in UTC
          operator: "<"
        }
      ],
      operator: "&"
    }
  end
end
