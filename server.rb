url = {list: "/wallpaper", 
	img: "/wallpaper/:img", 
	images: "/images/:img",
	wallpaper: "/wallpaper/:img/:width/:height"}

get '/' do
	@wallpapers = source_images.map{|a| get_name a}.sort
	erb :index
end

get url[:images] do
	file = thumb_image(params[:img])
	file = make_thumb(params[:img]) unless File.exists? file
	send_file(file, {:disposition => "inline", :filename => file})
end	
get url[:list] do
	list = []
	source_images.each {|f|
		id = get_name f
		list << link(url[:img].gsub(":img",id),id)
	}
	list.join("<br/>")
end

get url[:img] do
	i = params[:img]
        o = ["<img src=\"../#{i}.#{source_ext}\">"]
        o << "Try these: "
        ["1024_768","1600_900","2560_1920"].each do |r|
                x = r.tr("_","x")
                s = r.tr("_","/")
                o << "<a href='#{url[:wallpaper].gsub(":img",i).gsub(":width/:height", s)}'>#{x}</a>"
        end
        o << "Or, enter whatever you like"
        o.join("<br/>")
end

get url[:wallpaper].split("/")[0..-2].join("/") do
	"Height not specified"
end

get url[:wallpaper] do
	err = "";
	
	image = params[:img]

	unless File.exists? base_image image
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

        if w > 3840 || h > 2160
                err = "Slow down there, bucko! I can't do anything bigger than 4K"
        end
	
	unless err.length > 0
		debug "Got a request for #{image} with dimensions #{w}x#{h} in format #{ext}"
		file = File.join(created_image_dir, img_name(image, w, h, ext))
		
		unless File.exists? file
			debug "File doesn't yet exist, create it!~"
			file, msg = make({file: base_image(image),
				     height: h,
				     width: w,
				     output_folder: "images"})

			debug "created #{file}"
		else 
			debug "File already existed. NOT creating"
		end

		unless file.nil?
			send_file(file, {:disposition => "inline", :filename => file})
		else
			msg
		end
	else
		"Whoopsie! #{err}"
	end
end

def make_thumb img
	file = base_image img
	fn = thumb_image img
	FileUtils.cp(file, fn)
	res = "150x150"
	x = ImageSorcery.new(fn)
	x.manipulate!(thumbnail: "#{res}>")
	x.manipulate!(extent: res,
		      resize: res,
		      gravity: "center",
		      background: x.base_color(1,1))

	return fn
end

def img_name i, w, h, e; "#{i}_#{w}x#{h}.#{e}"; end

def debug msg; puts msg if ENV["DEBUG"]; end
def get_name str; str.split("/").last.split(".").first; end
def source_image_dir;  ENV["OPENSHIFT_DATA_DIR"] || "public"; end
def created_image_dir; ENV["OPENSHIFT_TMP_DIR"] || "images"; end
def js_image_dir; "images"; end
def thumb_image_dir; File.join(source_image_dir, "thumb"); end
def source_ext;        "jpg";    end
def created_ext;       "png";    end
def source_images; Dir.glob(File.join(source_image_dir, "*.#{source_ext}")); end
def js_base_image image; File.join(js_image_dir, image); end
def base_image image; File.join(source_image_dir, "#{image}.#{source_ext}"); end
def thumb_image image; File.join(thumb_image_dir, "#{image}.#{source_ext}"); end
def link href, link=href; "<a href=\"#{href}\">#{link}</a>"; end
def sub h, sym, t; s = ":"+sym.to_s; h[sym].gsub(s,t); end

def make args
	start  = Time.now.to_f

        file = args[:file]
        w = args[:width]
	h = args[:height] 
	output_folder = args[:output_folder]

        name = get_name file
        ext = created_ext
	resolution = "#{w}x#{h}"
	buffer = "#{w/10*9}x#{h/10*9}"

        debug "Converting #{file}"
	i = ImageSorcery.new file

	points = [1, iw/2, iw].product([1,ih/2,ih])
	points.delete_at(4) # rmv center point

	color = points.map{|x,y| i.color_at(x,y)}
		.inject(Hash.new(0)) { |h, e| h[e] += 1 ; h }
		.sort_by{|k,v| v}.last.first

	
	fn = File.join(output_folder, img_name(name, w, h, ext))

	FileUtils.cp(file,fn)

	x = ImageSorcery.new(fn)

	x.convert(fn, {trim: true})

	x.manipulate!(extent: buffer,
		      resize: buffer,
		      gravity: "SouthEast",
		      background: color)

	x.manipulate!(extent: resolution,
		      resize: resolution,
		      background: color)

	debug "New file in #{fn}\nProcessed in: #{(Time.now.to_f - start).round(3)} ms"
	return fn,""
end

