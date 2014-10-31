require 'sinatra'
require 'json'

url = {list: "/wallpaper", 
	img: "/wallpaper/:img", 
	wallpaper: "/wallpaper/:img/:width/:height"}

get '/' do
	"Gyprock API"+
	"<dt><code>#{link url[:list]}</code> <dd>list of images</dt>"+
	"<dt><code>#{link url[:img]}</code> <dd>image information</dt>"+
	"<dt><code>#{link url[:wallpaper]}</code> <dd>wallpaper in your dimensions</dt>"
end

get url[:list] do
	list = []
	Dir.glob(File.join(source_image_dir, "*.#{source_ext}")).each {|f|
		id = get_name f
		list << link(url[:img].gsub(":img",id),id)
		#list << "<a href='#{url[:img].gsub(":img",id)}'>#{id}</a>" 
	}
	list.join("<br/>")
end

get url[:img] do
	i = params[:img]
	"#{i} <img src=\"../#{i}.#{source_ext}\"><br/>"+
	"Try these: <a href='#{url[:wallpaper].gsub(":img",i).gsub(":width/:height", "1024/786")}'>1024x768</a>"
end

get url[:wallpaper].split("/")[0..-2].join("/") do
	"Height not specified"
end

get url[:wallpaper] do
	err = "";
	
	image = params[:img]

	unless File.exists? File.join(source_image_dir, image+".#{source_ext}") 
		err = "Image invalid identifier"
	end

	w = (params[:width]).to_i || 0
	h = (params[:height]).to_i || 0

	ext = created_ext

	if w == 0 
	 	err = "Width needs to be an integer greater than 0"
	end

	if h == 0 
		err = "Height needs to be an integer greater than 0"
	end
	
	unless err.length > 0
		debug "we'll gen an image for #{image} with dimensions #{w}x#{h} in format #{ext}"
		file = File.join(created_image_dir, img_name(image, w, h, ext))
		
		unless File.exists? file
			file = make({file: File.join(source_image_dir, "#{image}.#{source_ext}"),
				     height: h,
				     width: w,
				     output_folder: "images"})

			debug "created #{file}"
		end


		send_file(file, {:disposition => "inline", :filename => file})
	else
		"Whoopsie! #{err}"
	end
end

def img_name i, w, h, e; "#{i}_#{w}x#{h}.#{e}"; end

def debug msg; puts msg if ENV["DEBUG"]; end

def get_name str; str.split("/").last.split(".").first; end

def source_image_dir;  "public"; end
def source_ext;        "jpg";    end
def created_image_dir; "images"; end
def created_ext;       "png";    end
def link href, link=href; "<a href=\"#{href}\">#{link}</a>"; end
def sub h, sym, t; s = ":"+sym.to_s; h[sym].gsub(s,t); end

def make args
        file = args[:file]
        name = get_name file
        w = args[:width]
	h = args[:height] 
	output_folder = args[:output_folder]
        ext = created_ext

        debug "Converting #{file}"
	i = ImageSorcery.new file

        unless (i.background == i.base_color) then
                debug "Error processing #{file}: Background color #{i.background} does not match" \
                        "base colour #{i.base_color}. Manual intervention required"
        else
                start  = Time.now.to_f
		resolution = "#{w}x#{h}"
                buffer = "#{w/10*9}x#{h/10*9}"
		
		fn = File.join(output_folder, img_name(name, w, h, ext))
        
	        debug "FILE: #{file} to #{fn}, resolution: #{resolution}, full args: #{args}"
        
	        FileUtils.cp(file,fn)

                x = ImageSorcery.new(fn)

                x.manipulate!(extent: buffer,
                              resize: buffer,
                              gravity: "SouthEast",
                              background: i.background)

                x.manipulate!(extent: resolution,
                              resize: resolution,
                              background: i.background)

                debug "New file in #{fn}"
                debug "Processed in: #{(Time.now.to_f - start).round(3)} ms"
                return fn
        end
end

