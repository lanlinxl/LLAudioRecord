#
# Be sure to run `pod lib lint LLAudioRecord.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'LLAudioRecord' #存储库名称
  s.version          = '1.0.0' #版本号，与tag值一致
  s.summary          = 'Add background music to the recording'    #组件描述
  s.description      = <<-DESC  #描述


TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/yizhixiafancai/LLAudioRecord' #项目主页，不是git地址
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' } #开源协议
  s.author           = { 'lanlin' => 'lanlin0806@icloud.com' } #作者
  s.source           = { :git => 'https://github.com/yizhixiafancai/LLAudioRecord.git', :tag => s.version.to_s } #更换为github的远程仓库索引
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '9.0'
  s.static_framework = true
  s.source_files = 'LLAudioRecord/Classes/**/*'
  s.pod_target_xcconfig = { 'VALID_ARCHS' => 'x86_64 armv7 arm64' }
  s.swift_version = '5.0'
  s.vendored_frameworks = 'LLAudioRecord/Classes/Frameworks/*.framework'
  s.frameworks = 'UIKit', 'AVFoundation'
  # s.resource_bundles = {
  #   'LLAudioRecord' => ['LLAudioRecord/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
end
