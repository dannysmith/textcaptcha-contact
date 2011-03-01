%w(rubygems sinatra net/http rexml/document digest/md5 pony sinatra/flash).each {|r| require r}

enable :sessions

configure do
  set :haml, {:format => :html5 }
  set :environment, :development
end

def captcha
  @captcha_a = []
  begin
    #Get and parse text captcha data.
    c_data = Net::HTTP.get(URI.parse 'http://textcaptcha.com/api/1nrlupzni78rwgw08cck4ww0w')
    doc = REXML::Document.new(c_data)
    doc.elements.each("captcha/question") { |q| @captcha_q = q.first}
    doc.elements.each("captcha/answer") { |a| @captcha_a << a.first}
  rescue
    #Or default to this if it breaks.
    puts "CAPTCHA ERROR"
    @captcha_q = "Is ice hot or cold?"
    @captcha_a << Digest::MD5.hexdigest("cold")
  end

end

get '/styles.css' do
  content_type 'text/css', :charset => 'utf-8'
  sass :"sass/styles"
end

get '/' do
  captcha
  haml :index
end

post '/contact' do
  
  #TODO: Abstract this content so that the methods can be reused for AJAX calls and in-browser validation.
  
  #Check that catchpa matches one of the allowed answers
  captcha_encoded = Digest::MD5.hexdigest(params[:captcha].downcase)
  captcha_valid = false
  params[:l33g5].each_value do |v|
    captcha_encoded == v ? captcha_valid = true : false
  end
  
  #Check that fields aren't empty and that email is Valid.
  details_valid = (!params[:name].empty?) && (!params[:message].empty?) && (!params[:email].match(/^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i).nil?)
  
  #If it's all ok, try sending an email.
  if captcha_valid && details_valid

    if Pony.mail(:to => "danny@dasmith.co.uk", 
        :from => params[:email], 
        :subject=> "Message from #{params[:name]} (#{params[:email]})",
        :body => "Website:  #{params[:website]}\n\nMessage:\n\n#{params[:message]}\n\n#{params[:email]}",
        :via => :smtp, :via_options => {
          :address        => 'smtp.gmail.com',
          :port           => '587',
          :user_name      => 'danny@dasmith.co.uk',
          :password       => '**********',
          :authentication => :plain,
          :domain         => "dasmith.co.uk"
         }
        )
        
      flash[:message] = "Thanks, I'll be in touch soon."
      puts "Email Sent OK"
    else #If it couldn't send show error message in flash.
      flash[:message] = "I'm sorry, my contact form isn't working today. Could you email me at <a href=\"mailto:danny@dasmith.co.uk\">danny@dasmith.co.uk</a> instead?"
      puts "Email Sending Error"
    end
    
    redirect '/'
  else
    #If there's a validation problem, display helpful message
    flash[:message] = "There's something not quite right with your message.<ul><li>Have you filled in your name and email?</li><li>Is your email correct</li><li>Have your typed a message for me?</li><li>Did you answer the andti-robot question correctly?</li></ul>"
    puts "Contact Form Validation Error"
    redirect '/'
  end
end
