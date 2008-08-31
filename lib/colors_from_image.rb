require 'RMagick'
include Magick

module ColorsFromImage

   def self.light?(c)
     Pixel.from_color(c).intensity >= (MaxRGB / 2.0)
   end 

   def self.dark?(c)
     !self.light?(c)
   end 

   def self.to_hex(c)
      return if c.nil?
      "#%02x%02x%02x" % [(c.red / (MaxRGB + 1.0) * 256).to_i,(c.green / (MaxRGB + 1.0) * 256).to_i,(c.blue / (MaxRGB + 1.0) * 256).to_i]
   end

   def self.color_difference(c1,c2)
      ([c1.red,c2.red].max - [c1.red,c2.red].min) + ([c1.green,c2.green].max - [c1.green,c2.green].min) +
              ([c1.blue,c2.blue].max - [c1.blue,c2.blue].min)
   end

   def self.background_color(img)
      bkg = []
      bkg[0] = img.pixel_color(0,0)
      bkg[1] = img.pixel_color(0,img.rows-1)
      bkg[2] = img.pixel_color(img.columns-1,img.rows-1)
      bkg[3] = img.pixel_color(img.columns-1,0)

      h = s = l = o = 0

      0.upto(3) do |n|
         hsl = bkg[n].to_HSL()
         h += hsl[0]
         s += hsl[1]
         l += hsl[2]
         o += bkg[n].opacity
      end

      h /= 4
      s /= 4
      l /= 4
      o /= 4

      o > 0 ? nil : Pixel.from_HSL([h,s,l])
   end

   def self.get_colors(file_name)
      cat = Image.read(file_name).first
      cat.fuzz = 0.5
      i = cat.quantize(10, RGBColorspace, false)
      hist = i.color_histogram

      bg_color = self.background_color(i)
      if bg_color.is_a? String
         bg_color = Pixel.from_color(bg_color)
      end

      if bg_color
         bg = self.to_hex(bg_color)
         RAILS_DEFAULT_LOGGER.debug "[#{file_name}] Background color: #{bg}" if bg
      end

      cols = hist.sort_by {|a| a[1]}.select{|a|a[0].opacity==0 && (bg.nil? || self.to_hex(a[0]) != bg)}.reverse

      sat = hist.sort_by{|a|
         hsl = a[0].to_HSL
         (hsl[1]+0.01) * (hsl[2]+0.01) * a[1]
      }.select{|a|a[0].opacity==0 && self.to_hex(a[0]) != bg}.reverse

      colors = []

      sat.each do |c|
         hue, saturation, luminance = c[0].to_HSL
#         RAILS_DEFAULT_LOGGER.debug "#{file_name} %5d: %2.2f %2.2f %2.2f %s" % [c[1], hue, saturation, luminance, to_hex(c[0])]

         new_color = true
         colors.each do |col|
            new_color = false if self.color_difference(col,c[0]) < (MaxRGB * 0.381)
         end

         if new_color
            colors << c[0]
         end

      end

      colors = colors.sort_by {|a| a.to_HSL[1]}.reverse[0..2].map{|c| self.to_hex(c)}

      RAILS_DEFAULT_LOGGER.debug "[#{file_name}] Colors:"
      colors.each do |c|
         RAILS_DEFAULT_LOGGER.debug "[#{file_name}] #{c}"
      end

      [bg] + colors
   end
end
