require 'rubygems'
require 'bundler'
Bundler.require
require 'json'
require 'color'
require './server.rb'
require './image_sorcery.rb'
run Sinatra::Application
