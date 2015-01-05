set :source_image_dir,  ENV["OPENSHIFT_DATA_DIR"] || "public"
set :thumb_image_dir,   "#{settings.source_image_dir}/thumb"
set :created_image_dir, ENV["OPENSHIFT_TMP_DIR"] || "images"

EXT="png"

get '/' do
	@wallpapers = source_images.map{|a| get_name a}.sort
	erb :index
end

get "/images/:img" do
	file = thumb_image(params[:img])
	file = make_thumb(params[:img]) unless File.exists? file
	send_file(file, {:disposition => "inline", :filename => file})
end	

["/wallpaper/:img", "/wallpaper/:img/:x"].each do |path|
	get path do
		"Must specify height and width: `/wallpaper/:img/:width/:height"
	end
end

get "/wallpaper/:image/:width/:height" do
	err = "";
	
	image = params[:image]

	unless File.exists? base_image image
		err = "Image invalid identifier"
	end

	w = (params[:width]).to_i || 0
	h = (params[:height]).to_i || 0

	err = "Width needs to be an integer greater than 0" if w == 0 

	err = "Height needs to be an integer greater than 0" if h == 0 

	err = "Slow down there, bucko! I can't do anything bigger than 4K" if w > 3840 || h > 2160
	
	unless err.length > 0
		debug "Got a request for #{image} with dimensions #{w}x#{h} in format #{EXT}"
		file = File.join(settings.created_image_dir, img_name(image, w, h, EXT))
		
		unless File.exists? file
			start = Time.now().to_f; debug "Converting #{file}"
			
			FileUtils.cp(base_image(image), file)
			color = base_color file

			trim! file: file
			resize! width: w * 0.9, height: h * 0.9, file: file, fill: color, gravity: "SouthEast"
			resize! width: w,       height: h,       file: file, fill: color, gravity: "NorthWest"

			debug "New file in #{file}\nProcessed in: #{(Time.now.to_f - start).round(3)} ms"
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


def trim! args
	i = ImageSorcery.new(args[:file])
	i.convert(args[:file], {trim: true})	
end

def resize! args
	i = ImageSorcery.new(args[:file])
	dimension = "#{args[:width]}x#{args[:height]}" 
	i.manipulate!(extent: dimension, 
		      resize: dimension,
		      gravity: args[:gravity], 
		      background: args[:fill]
	)
end

def make_thumb img
	file = base_image img
	fn = thumb_image img
	FileUtils.cp(file, fn)
	ImageSorcery.new(fn).manipulate!(thumbnail: "150x150>")
	resize! width: 150, height: 150, file: fn, fill: base_color(file), gravity: "center"
	return fn
end

def img_name i, w, h, e
	"#{i}_#{w}x#{h}.#{e}"
end
def debug msg; 
	puts msg if ENV["DEBUG"]
end
def get_name str 
	str.split("/").last.split(".").first
end
def source_images 
	Dir.glob(File.join(settings.source_image_dir, "*.#{EXT}"))
end
def base_image image 
	File.join(settings.source_image_dir, "#{image}.#{EXT}")
end
def thumb_image image
	File.join(settings.thumb_image_dir, "#{image}.#{EXT}")
end

def base_color img
	i = ImageSorcery.new img
	iw = i.width
	ih = i.height

	points = [1, iw/2, iw].product([1,ih/2,ih])
	points.delete_at(4) # remove center point

	color = points.map{|x,y| i.color_at(x,y)}
		.inject(Hash.new(0)) { |f, e| f[e] += 1 ; f }
		.sort_by{|k,v| v}.last.first
	return color
end
