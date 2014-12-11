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
  s.summary          = "A short description of AVFoundationCameraController."
  s.description      = <<-DESC
                       An optional longer description of AVFoundationCameraController

                       * Markdown format.
                       * Don't worry about the indent, we strip it!
                       DESC
  s.homepage         = "https://github.com/<GITHUB_USERNAME>/AVFoundationCameraController"
  # s.screenshots     = "www.example.com/screenshots_1", "www.example.com/screenshots_2"
  s.license          = 'MIT'
  s.author           = { "kent013" => "kentaro.ishitoya@gmail.com" }
  s.source           = { :git => "https://github.com/<GITHUB_USERNAME>/AVFoundationCameraController.git", :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.platform     = :ios, '7.0'
  s.requires_arc = true

  s.source_files = 'Pod/Classes'
  s.resource_bundles = {
    'AVFoundationCameraController' => ['Pod/Assets/*.png']
  }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  s.frameworks = ['AssetsLibrary']
  # s.dependency 'AFNetworking', '~> 2.3'
end