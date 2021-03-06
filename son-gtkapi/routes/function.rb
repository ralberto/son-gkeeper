##
## Copyright (c) 2015 SONATA-NFV [, ANY ADDITIONAL AFFILIATION]
## ALL RIGHTS RESERVED.
## 
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
## 
##     http://www.apache.org/licenses/LICENSE-2.0
## 
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.
## 
## Neither the name of the SONATA-NFV [, ANY ADDITIONAL AFFILIATION]
## nor the names of its contributors may be used to endorse or promote 
## products derived from this software without specific prior written 
## permission.
## 
## This work has been performed in the framework of the SONATA project,
## funded by the European Commission under Grant number 671517 through 
## the Horizon 2020 and 5G-PPP programmes. The authors would like to 
## acknowledge the contributions of their colleagues of the SONATA 
## partner consortium (www.sonata-nfv.eu).
# encoding: utf-8
require 'sinatra/namespace'
class GtkApi < Sinatra::Base

  register Sinatra::Namespace
  
  namespace '/api/v2/functions' do
    # GET many functions
    get '/?' do
      began_at = Time.now.utc
      log_message = 'GtkApi::GET /api/v2/functions/?'
      logger.debug(log_message) {'entered with '+query_string}
    
      @offset ||= params[:offset] ||= DEFAULT_OFFSET 
      @limit ||= params[:limit] ||= DEFAULT_LIMIT
      logger.debug(log_message) {"params=#{params}"}
      content_type :json
     
      token = get_token( request.env, log_message)
      if (token.to_s.empty?)
        count_functions_metadata_queries(labels: {result: "bad request", uuid: '', elapsed_time: (Time.now.utc-began_at).to_s})
        json_error 400, 'Token not provided', log_message
      end
      
      unless User.authorized?(token: token, params: {path: '/functions', method: 'GET'})
        count_functions_metadata_queries(labels: {result: "forbidden", uuid: params[:uuid], elapsed_time: (Time.now.utc-began_at).to_s})
        json_error 403, "Forbidden: user could not be authorized to get metadata for functions with params #{params}", log_message
      end

      functions = FunctionManagerService.find(params)
      unless functions
        count_functions_metadata_queries(labels: {result: "not found", uuid: '', elapsed_time: (Time.now.utc-began_at).to_s})
        json_error 404, "No function with params #{params} was found", log_message
      end
      
      logger.debug(log_message) {"Found functions #{functions}"}
      case functions[:status]
      when 200
        logger.debug(log_message) {"links: request_url=#{request_url}, limit=#{@limit}, offset=#{@offset}, total=#{functions[:count]}"}
        links = build_pagination_headers(url: request_url, limit: @limit.to_i, offset: @offset.to_i, total: functions[:count].to_i)
        logger.debug(log_message) {"links: #{links}"}
        headers 'Link'=> links, 'Record-Count'=> functions[:count].to_s
        count_functions_metadata_queries(labels: {result: "ok", uuid: '', elapsed_time: (Time.now.utc-began_at).to_s})
        halt 200, functions[:items].to_json
      else
        count_functions_metadata_queries(labels: {result: "not found", uuid: '', elapsed_time: (Time.now.utc-began_at).to_s})
        json_error 404, "No functions with #{params} were found", log_message
      end
    end
  
    # GET function by uuid
    get '/:uuid/?' do
      began_at = Time.now.utc
      log_message = 'GtkApi::GET /api/v2/functions/:uuid/?'
      logger.debug(log_message) {"entered with #{params[:uuid]}"}
      content_type :json
    
      token = get_token( request.env, log_message)
      if (token.to_s.empty?)
        count_functions_metadata_queries(labels: {result: "bad request", uuid: '', elapsed_time: (Time.now.utc-began_at).to_s})
        json_error 400, 'Token not provided', log_message
      end

      unless valid?(params[:uuid])
        count_function_metadata_queries(labels: {result: "bad request", uuid: params[:uuid], elapsed_time: (Time.now.utc-began_at).to_s})
        json_error 404, "Function #{params[:uuid]} not valid", log_message
      end

      unless User.authorized?(token: token, params: {path: '/functions', method: 'GET'})
        count_service_metadata_queries(labels: {result: "forbidden", uuid: params[:uuid], elapsed_time: (Time.now.utc-began_at).to_s})
        json_error 403, "Forbidden: user could not be authorized to get metadata for function #{params[:uuid]}", log_message
      end
      
      function = FunctionManagerService.find_by_uuid(params[:uuid])
      if !function[:count] || function[:items].empty?
        count_function_metadata_queries(labels: {result: "not found", uuid: params[:uuid], elapsed_time: (Time.now.utc-began_at).to_s})
        json_error 404, "Function #{params[:uuid]} not found", log_message
      end
      count_function_metadata_queries(labels: {result: "ok", uuid: params[:uuid], elapsed_time: (Time.now.utc-began_at).to_s})
      logger.debug(log_message) {"leaving with #{function}"}
      headers 'Record-Count'=> '1'
      halt 200, function[:items].to_json
    end
  end
  
  namespace '/api/v2/admin/functions' do
    get '/logs/?' do
      log_message = 'GtkApi::GET /admin/functions/logs'
      logger.debug(log_message) {'entered'}
      url = FunctionManagerService.class_variable_get(:@@url)+'/admin/logs'
      log = FunctionManagerService.get_log(url: url, log_message:log_message)
      logger.debug(log_message) {'leaving with log='+log}
      headers 'Content-Type' => 'text/plain; charset=utf8', 'Location' => '/'
      halt 200, log
    end
  end

  private
  
  def count_functions_metadata_queries(labels:)
    name = __method__.to_s.split('_')[1..-1].join('_')
    desc = "how many function metadata queries have been made"
    ServiceManagerService.counter_kpi({name: name, docstring: desc, base_labels: labels.merge({method: 'GET', module: 'functions'})})
  end

  def count_function_metadata_queries(labels:)
    name = __method__.to_s.split('_')[1..-1].join('_')
    desc = "how many function metadata queries by uuid have been made"
    ServiceManagerService.counter_kpi({name: name, docstring: desc, base_labels: labels.merge({method: 'GET', module: 'functions'})})
  end
end
