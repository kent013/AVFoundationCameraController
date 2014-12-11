#
# Be sure to run `pod lib lint AVFoundationCameraController.podspec' to ensure this is a
# valid spec and remove all comments before submitting the spec.
#
# Any lines starting with a # are optional, but encouraged
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "AVFoundationCameraController"
  s.version          = "0.1.0"
  s.summary          = "A Camera View uses AVFoundation."
  s.description      = <<-DESC
                       a camera view uses AVFoundation.
                       DESC
  s.homepage         = "https://github.com/kent013/AVFoundationCameraController"
  s.license          = 'MIT'
  s.author           = { "kent013" => "kentaro.ishitoya@gmail.com" }
  s.source           = { :git => "https://github.com/kent013/AVFoundationCameraController.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/kent013'

  s.platform     = :ios, '7.0'
  s.requires_arc = true
  s.source_files = 'Pod/Classes'
  s.frameworks = ['AssetsLibrary']
end
