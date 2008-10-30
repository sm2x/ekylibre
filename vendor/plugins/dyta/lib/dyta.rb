# Dyta
module Dyta

  module Controller


    def self.included(base) #:nodoc:
      base.extend(ClassMethods)
    end


    module ClassMethods
      
      include ERB::Util
      include ActionView::Helpers::TagHelper
      include ActionView::Helpers::UrlHelper


      # Add methods to display a dynamic table
      def define_dyta(name, options={}, &block)
        model = (options[:model]||name).to_s.classify.constantize
        definition = Dyta.new(name, model, options)
        yield definition

        # List method
        condition = ''
        if options[:conditions]
          
        end


        code  = "def "+name.to_s+"_list\n"
        code += "  @"+name.to_s+"="+model.to_s+".find(:all)\n"
        code += "  if request.xhr?\n"
        code += "    render :text=>"+name.to_s+"_build\n"
        code += "  end\n"
        code += "end\n"
        code += "protected\n"

        # Build method
        if definition.procedures.size>0
          process = ''
          for procedure in definition.procedures
            process += "+' '+" unless process.blank?
            process += "link_to(lc(:"+procedure.name.to_s+").gsub(/\ /,'&nbsp;'), "+
                               procedure.options.inspect+", :class=>'button')"
          end      
          process = "'"+content_tag(:tr, content_tag(:td, "'+"+process+"+'", :class=>"menu", 
                                                     :colspan=>definition.columns.size))+"'"
        end

        record = 'r'
        header = ''
        body = ''
        for column in definition.columns
          header += content_tag(:th, h(column.header), :class=>(column.action? ? 'act' : 'col'))
          body += body.blank? ? "      line  = " : "      line += "
          case column.nature
          when :column
            style = options[:style]||''
            css_class = ''
            datum = column.data(record)
            if column.datatype==:boolean
              datum = 'value_image('+datum+')'
              style = 'text-align:center;'
            end
            if column.options[:url]              
              datum = 'link_to('+datum+', url_for('+column.options[:url].inspect+'.merge({:id=>'+column.record(record)+'.id})'
              css_class += ' url'
            elsif column.options[:mode]==:download# and !datum.nil?
              datum = 'link_to(value_image("download"), url_for_file_column('+column.data(record)+",'"+column.name+"'))"
              style = 'text-align:center;'
              css_class += ' act'
            end
            if column.options[:name]==:color
              css_class += ' color'
              style = "background: #'+"+column.data(record)+"+'; color:#'+viewable("+column.data(record)+")+';"
            end
            body += "content_tag(:td, "+datum+", :class=>'"+column.datatype.to_s+css_class+"'"
            body += ", :style=>'"+style+"'" unless style.blank?
            body += ")"
          when :action 
            body += "content_tag(:td, "+column.operation(record)+", :class=>'act')"
          else 
            body += "content_tag(:td, '&nbsp;&empty;&nbsp;')"
          end
          body += "\n"
        end

        header = content_tag(:tr, header)

        code += "def "+name.to_s+"_build\n"
        code += "  if @"+name.to_s+".size>0 \n"
        code += "    header = '"+header+"'\n"
        code += "    reset_cycle('dyta')\n"
        code += "    body = ''\n"
        code += "    for "+record+" in @"+name.to_s+"\n"
        code += body
        code += "      body += content_tag(:tr, line, :class=>'data '+cycle('odd','even', :name=>'dyta'))\n"
        code += "    end\n"
        code += "    text = header+body\n"
        code += "  else\n"
        code += "    text = '"+content_tag(:tr,content_tag(:td,l(:no_records).gsub(/\'/,'&apos;')))+"'\n"
        code += "  end\n"
        code += "  text = "+process+"+text\n" unless process.nil?
        code += "  text = content_tag(:table, text, :id=>'"+name.to_s+"', :class=>:list)\n"
        code += "  text = content_tag(:div, text)\n"
        code += "  text = content_tag(:h3,  "+h(options[:label])+")+text\n" unless options[:label].nil?
        code += "  text = content_tag(:div, text, :class=>'futo')\n"
        code += "  text = content_tag(:h2,  "+options[:title]+", :class=>'futo')+text\n" unless options[:title].nil?
        code += "  text\n"
        code += "end\n"

        # Finish
        puts code
        module_eval(code)
      end

    end

    def value_image(value)
      unless value.nil?
        image = nil
        case value.to_s
        when "true" : image = "true"
        when "false" : image = nil
        else image =  value.to_s
        end
        #      "<div align=\"center\">"+image_tag("buttons/"+image+".png", :border => 0, :alt=>image.t, :title=>image.t)+"</div>" unless image.nil?
        image_tag("buttons/"+image+".png", :border => 0, :alt=>l(image), :title=>l(image)) unless image.nil?
      end
    end
  



  end


  # Dyta represents a DYnamic TAble
  class Dyta
    attr_reader :name, :model, :options
    attr_reader :columns, :procedures
    
    def initialize(name, model, options)
      @name    = name
      @model   = model
      @options = options
      @columns = []
      @procedures = []
    end
    
    def column(name, options={})
      @columns << DytaElement.new(model,:column,name,options)
    end
    
    def action(name, options={})
      @columns << DytaElement.new(model,:action,name,options)
    end
    
    def procedure(name, options={})
      @procedures << DytaElement.new(model,:procedure,name,options)
    end
  end


  # Dyta Element represents an element of a Dyta
  class DytaElement
    attr_accessor :name, :options
    attr_reader :nature
    include ERB::Util

    def initialize(model, nature, name, options={})
      @model   = model
      @nature  = nature
      @name    = name
      @options = options
      @column  = @model.columns_hash[@name.to_s] if @nature == :column
    end

    def action?
      @nature == :action
    end

    def header
      if @options[:title].nil?
        case @nature
        when :column
          if @options[:through] and @options[:through].is_a?(Symbol)
            raise Exception.new("Unknown reflection :#{@options[:through].to_s} for the ActiveRecord: "+@model.to_s) if @model.reflections[@options[:through]].nil?
            @model.columns_hash[@model.reflections[@options[:through]].primary_key_name].human_name
          elsif @options[:through] and @options[:through].is_a?(Array)
            model = @model
            (@options[:through].size-1).times do |x|
              model = model.reflections[@options[:through][x]].options[:class_name].constantize
            end
            reflection = @options[:through][@options[:through].size-1].to_sym
            model.columns_hash[model.reflections[reflection].primary_key_name].human_name
          else
            @model.human_attribute_name(@name)
          end;
        when :action
          'ƒ'
        else 
          '-'
        end
      else
        @options[:title].to_s
      end
    end
    
    def datatype
      begin
        @column.send(:type)
      rescue
        nil
      end
    end

    def data(record='record')
      if @options[:through]
        through = [@options[:through]] unless @options[:through].is_a?(Array)
        foreign_record = record
        through.size.times { |x| foreign_record += '.'+through[x].to_s }
        '('+foreign_record+'.nil? ? nil : '+foreign_record+'.'+@name.to_s+')'
      else
        record+'.'+@name.to_s
      end
    end

    def record(record='record')
      if @options[:through]
        through = [@options[:through]] unless @options[:through].is_a?(Array)
        foreign_record = record
        through.size.times { |x| foreign_record += '.'+through[x].to_s }
        foreign_record
      else
        record
      end
    end

    def operation(record='record')
      link_options = {}
      link_options[:confirm] = l(@options[:confirm]) unless @options[:confirm].nil?
      link_options[:method]  = @options[:method]     unless @options[:method].nil?
      link_options = link_options.inspect.to_s
      link_options = link_options[1..link_options.size-2]
      image_title = @options[:title]||@name.to_s.humanize
      image_file = "buttons/"+(@options[:image]||@name).to_s+".png"
      image_file = "buttons/unknown.png" unless File.file? "#{RAILS_ROOT}/public/images/"+image_file
      code  = "link_to(image_tag('"+image_file+"', :border=>0, :alt=>'"+image_title+"')"
      code += ", {:action=>:"+@name.to_s+", :id=>"+record+".id}"
      code += ", {:id=>'"+@name.to_s+"_'+"+record+".id.to_s"+(link_options.blank? ? '' : ", "+link_options)+"}"
      code += ")"
      code
    end
    


  end


  module View
    def dyta(name)
      # Asynchronous load
#      code = content_tag :table, nil, :id=>name.to_s
#      js = remote_function :update=>name.to_s, :url=>{:action=>name.to_s+'_list'}
#      code+javascript_tag(js)
      self.controller.send(name.to_s+'_build')
    end
  end

end
