# encoding: utf-8

module Quotex
  class QuotesController < ApplicationController
    before_filter :require_employee
    before_filter :load_rfq
  
    helper_method :has_show_right?, :has_edit_right?, :has_create_right?, :total_value, :link_to_remove_actions, :rfq_ready?
      
    def index
      @title = '报价'
      if sales_dept_head? || corp_head? || ceo?
        @quotes = @rfq.present? ? @rfq.quotes.order("quote_date DESC").paginate(:per_page => 40, :page => params[:page]) : Quote.where('quote_date > ?', Time.now - 365.day).order("quote_date DESC").paginate(:per_page => 40, :page => params[:page])
      else
        @quotes = @rfq.present? ? @rfq.quotes.active_quote.order("quote_date DESC").paginate(:per_page => 40, :page => params[:page]) : Quote.active_quote.where('quote_date > ?', Time.now - 365.day).order("quote_date DESC").paginate(:per_page => 40, :page => params[:page])
      end    
    end
  
    def show
      @title = '报价内容'
      @quote = @rfq.quotes.find(params[:id])
      if !has_show_right?(@rfq)
        redirect_to URI.escape(SUBURI + "/view_handler?index=0&msg=权限不足！")
      end
    end
  
    def new
      @title= "新报价" 
      if has_create_right?(@rfq)
        if rfq_ready?(@rfq) 
          @quote = @rfq.quotes.new()
          @quote.test_items << @rfq.test_items
        else
          redirect_to URI.escape(SUBURI + "/view_handler?index=0&msg=无测试项目或工程师！")
        end
      else
        redirect_to URI.escape(SUBURI + "/view_handler?index=0&msg=无权限！")  
      end
    end
  
    def create
      if has_create_right?(@rfq) && rfq_ready?(@rfq)
        if params[:quote][:test_item_ids].present?
          @quote = @rfq.quotes.new(params[:quote], :as => :role_new)
          @quote.input_by_id = session[:user_id]
          @quote.test_items =  TestItem.find_all_by_id(params[:quote][:test_item_ids]) 
          if @quote.save!
            redirect_to URI.escape(SUBURI + "/view_handler?index=0&msg=报价已保存!")
          else
            flash.now[:error] = "无法保存报价!"
            render 'new'
          end
        else
          redirect_to URI.escape(SUBURI + "/view_handler?index=0&msg=报价必须有测试项目或工程师！")
        end
      else
        redirect_to URI.escape(SUBURI + "/view_handler?index=0&msg=无权限！") 
      end
    end
  
    def edit
      @title= "批准报价"
      if has_edit_right?(@rfq)
        @quote = Quote.find(params[:id])
      else
        redirect_to URI.escape(SUBURI + "/view_handler?index=0&msg=无权限！")
      end
    end
  
    def update
      if has_edit_right?(@rfq)
        @quote = Quote.find(params[:id])
        @quote.input_by_id = session[:user_id]
        check_approved_by_dept_head(@quote, params[:quote][:approved_by_dept_head])
        check_approved_by_corp_head(@quote, params[:quote][:approved_by_corp_head])
        if @quote.update_attributes(params[:quote], :as => :role_update)
          redirect_to URI.escape(SUBURI + "/view_handler?index=0&msg=报价已更改!")
        else
          flash.now[:error] = '无法更改'
          render 'edit'
        end
      else
        redirect_to URI.escape(SUBURI + "/view_handler?index=0&msg=无权限！") 
      end
    end
    
    def search
      @quote = Quote.new
    end
    
    def search_results
      @quote = Quote.new(params[:quote], :as => :role_search)
      #seach params
      @search_params = search_params()
          
      @quotes = @quote.find_quotes
      @total = 0.0
      
      if @quotes
        @quotes.each do |q|
          @total += q.quoted_total
        end
      end
      
    end
    
    def stats
      @quote = Quote.new()
    end
    
    def stats_results
      @quote = Quote.new(params[:quote], :as => :role_search)
      @quotes_stats = @quote.find_quotes.where("quotes.cancelled = ?", false).order("quote_date DESC")
      @stats_params = "参数：" + params[:quote][:time_frame] + '，统计条数：'+@quotes_stats.count.to_s
      group_records(params[:quote][:time_frame]) 
      @stats_params += ', ' + Customer.find_by_id(params[:quote][:customer_id_s]).short_name if params[:quote][:customer_id_s].present?
      @stats_params += ', ' + User.find_by_id(params[:quote][:sales_id_s]).name if params[:quote][:sales_id_s].present?
  
      #return if @quotes_stats.blank?  #empty causes error in following code       
    end
    
    protected
  
    def search_params
      search_params = "参数："
      search_params += ', RFQ# ：' + params[:quote][:rfq_id_s] if params[:quote][:rfq_id_s].present?
      search_params += ' 开始日期：' + params[:quote][:earliest_created_at] if params[:quote][:earliest_created_at].present?
      search_params += ', 结束日期：' + params[:quote][:latest_created_at] if params[:quote][:latest_created_at].present?
      search_params += ', 账单类型 ：' + params[:quote][:invoice_type_s] if params[:quote][:invoice_type_s].present?
      search_params += ', 客户批准？ ：' + params[:quote][:not_approved_by_customer_s] if params[:quote][:not_approved_by_customer_s].present?
      search_params += ', 公司批准？ ：' + params[:quote][:not_approved_by_corp_s] if params[:quote][:not_approved_by_corp_s].present?
      search_params += ', 客户 ：' + Customer.find_by_id(params[:quote][:customer_id_s].to_i).short_name if params[:quote][:customer_id_s].present?
      search_params += ', 业务员 ：' + User.find_by_id(params[:quote][:sales_id_s].to_i).name if params[:quote][:sales_id_s].present?
      search_params
    end
  
    def group_records(time_frame)
        case time_frame 
        when '周'
          @quotes_stats = @quotes_stats.where("quote_date > ?", 2.years.ago).joins(:rfq).all(:select => "quote_date, sum(quoted_total) as revenue, count(DISTINCT(customer_id)) as num_customer, count(quotes.id) as num_quote", 
                                  :group => "strftime('%Y/%W', quote_date)")
                            
        when '月'
          @quotes_stats = @quotes_stats.where("quote_date > ?", 3.years.ago).joins(:rfq).all(:select => "quote_date, sum(quoted_total) as revenue, count(DISTINCT(customer_id)) as num_customer, count(quotes.id) as num_quote", 
                                  :group => "strftime('%Y/%m', quote_date)")                     
        when '季'
          @quotes_stats = @quotes_stats.where("quote_date > ?", 4.years.ago).joins(:rfq).all(:select => "quote_date, sum(quoted_total) as revenue, count(DISTINCT(customer_id)) as num_customer, count(quotes.id) as num_quote,
                                  CASE WHEN cast(strftime('%m', quote_date) as integer) BETWEEN 1 AND 3 THEN 1 WHEN cast(strftime('%m', quote_date) as integer) BETWEEN 4 and 6 THEN 2 WHEN cast(strftime('%m', quote_date) as integer) BETWEEN 7 and 9 THEN 3 ELSE 4 END as quarter", 
                                  :group => "strftime('%Y', quote_date), quarter")                                
        when '年'
          @quotes_stats = @quotes_stats.where("quote_date > ?", 5.years.ago).joins(:rfq).all(:select => "quote_date, sum(quoted_total) as revenue, count(DISTINCT(customer_id)) as num_customer, count(quotes.id) as num_quote",
                                  :group => "strftime('%Y', quote_date)")                         
        end   
        
    end    
    #if approved_by_CORP_head changed?
    def check_approved_by_corp_head(quote, new_value_str)
      if (quote.approved_by_corp_head.to_s != new_value_str) && (corp_head? || ceo?)
        if new_value_str.nil?
          quote.approve_date_corp_head = nil
          quote.corp_head_id = nil          
        else
          quote.approve_date_corp_head = Time.now
          quote.corp_head_id = session[:user_id]
        end
      end    
    end  
  
    #if approved_by_DEPT_head changed?
    def check_approved_by_dept_head(quote, new_value_str)
      if (quote.approved_by_dept_head.to_s != new_value_str) && (sales? && dept_head?)
        if new_value_str.nil?
          quote.approve_date_dept_head = nil
          quote.dept_head_id = nil          
        else
          quote.approve_date_dept_head = Time.now
          quote.dept_head_id = session[:user_id]
        end
      end    
    end  
      
    def has_create_right?(rfq)
      return true if session[:user_id] == rfq.sales_id && sales?
      return true if (sales_dept_head?) || corp_head? || ceo?            
    end
  
    def has_show_right?(rfq)
      return true if session[:user_id] == rfq.sales_id && sales?
      return true if session[:user_id] == rfq.emc_eng_id && eng?
      return true if session[:user_id] == rfq.safety_eng_id && eng?
      return true if acct? 
      return true if reporter?
      return true if dept_head? || corp_head? || ceo?
      
    end
    
    def has_edit_right?(rfq)
      return true if session[:user_id] == rfq.sales_id && sales?
      return true if sales_dept_head? || corp_head? || ceo?       
    end
    
    def rfq_ready?(rfq)
      rfq.test_items.present? && (rfq.emc_eng_id.present? || rfq.safety_eng_id.present?)    
    end
    
    def total_value(rfq)
      value = 0.00
      rfq.test_items.each do |ti|
        value += TestItem.find_by_id(ti.id).rate 
      end
      return value
    end
    
    def load_rfq
      @rfq = RfqxEmx::Rfq.find(params[:rfq_id]) if params[:rfq_id].present?
    end
    
    
  end

end