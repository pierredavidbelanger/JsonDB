Pod::Spec.new do |s|
  s.name = "JsonDB"
  s.version = "0.2.0"
  s.summary = "A simple in process database to store, query and manipulate JSON documents in Objective-C."
  s.description = s.summary
  s.homepage = "https://github.com/pierredavidbelanger/JsonDB"
  s.license = 'MIT'
  s.author = { "Pierre-David Bélanger" => "pierredavidbelanger@gmail.com" }
  s.source = { :git => "https://github.com/pierredavidbelanger/JsonDB.git", :tag => s.version.to_s }
  s.requires_arc = true
  s.source_files = 'JsonDB/*.{h,m}'
  s.public_header_files = 'JsonDB/*.h'
  s.private_header_files = 'JsonDB/*+Private.h'
  s.ios.deployment_target = '5.0'
  s.osx.deployment_target = '10.7'
  s.dependency 'FMDB', '~> 2.0'
end
