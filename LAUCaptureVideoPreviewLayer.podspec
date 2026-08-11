Pod::Spec.new do |s|
  s.name         = 'LAUCaptureVideoPreviewLayer'
  s.version      = '0.1.0'
  s.summary      = 'AVCaptureVideoPreviewLayer replacement for iOS with a Metal-based blur filter.'
# s.description  = <<-DESC
#                   * Markdown format.
#                   * Don't worry about the indent, we strip it!
#                  DESC
  s.homepage     = 'https://github.com/coletiv/LAUCaptureVideoPreviewLayer'
# s.screenshots  = "www.example.com/screenshots_1", "www.example.com/screenshots_2"
  s.license      = 'MIT'
  s.author       = { 'Luis Laugga' => 'luis@laugga.com' }
  s.source       = { :git => 'https://github.com/laugga/LAUCaptureVideoPreviewLayer.git', :tag => s.version.to_s }

  s.platform     = :ios, '17.0'
  s.ios.deployment_target = '17.0'
  s.requires_arc = true

  # Includes LAUCaptureVideoPreviewLayerShaders.metal, which is compiled into the
  # default metallib of the target that links the library
  s.source_files = 'lib/*'

  s.public_header_files = 'lib/*.h'
  s.prefix_header_file = 'support/LAUCaptureVideoPreviewLayer-Prefix.pch'
  s.frameworks = 'AVFoundation', 'UIKit', 'CoreGraphics', 'CoreVideo', 'QuartzCore', 'Metal'
end
