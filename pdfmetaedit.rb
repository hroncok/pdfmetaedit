#!/usr/bin/ruby
#
# Copyright (c) 2011, 2012, Miro Hrončok <miro@hroncok.cz>
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR
# IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

require 'tempfile'
require 'gtk2'
require 'gettext'
include GetText
bindtextdomain("pdfmetaedit")
require 'htmlentities'
coder = HTMLEntities.new

# Error window
def error_window (message)
	dialog = Gtk::MessageDialog.new(@window, 
									Gtk::Dialog::MODAL,
									Gtk::MessageDialog::ERROR,
									Gtk::MessageDialog::BUTTONS_OK,
							_("Error") )
	dialog.title = _("Error")
	dialog.secondary_text = message
	dialog.run
	dialog.destroy
end

# Is the file a PDF document?
def isPDF (file)
	return system("file -b '#{file}' | grep -q '^PDF document'")
end

# Open file
def open_file
	dialog = Gtk::FileChooserDialog.new(_("Open a PDF document"),
										@window,
										Gtk::FileChooser::ACTION_OPEN,
										nil,
										[Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
										[Gtk::Stock::OPEN, Gtk::Dialog::RESPONSE_ACCEPT])
	dialog.current_folder = `echo $HOME`.chomp
	#Filters
	pdf = Gtk::FileFilter.new
	pdf.name = _("PDF documents")
	pdf.add_mime_type("application/pdf")
	dialog.add_filter(pdf)
	allfiles = Gtk::FileFilter.new
	allfiles.name = _("All files")
	allfiles.add_pattern("*")
	dialog.add_filter(allfiles)
	# Action
	while true
		if dialog.run == Gtk::Dialog::RESPONSE_ACCEPT
			if isPDF(dialog.filename)
				filename = dialog.filename
				dialog.destroy
				break
			else
				error_window(_("Selected file") + _(" is not a PDF document."))
			end
		else
			dialog.destroy
			break
		end
	end
	# End
	return filename
end

# Save file as
def output_file(currentfolder)
	dialog = Gtk::FileChooserDialog.new(_("Save new file as"),
										@window,
										Gtk::FileChooser::ACTION_SAVE,
										nil,
										[Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
										[Gtk::Stock::OPEN, Gtk::Dialog::RESPONSE_ACCEPT])
	dialog.current_folder = currentfolder
	dialog.do_overwrite_confirmation = true
	#Filters
	pdf = Gtk::FileFilter.new
	pdf.name = _("PDF documents")
	pdf.add_mime_type("application/pdf")
	dialog.add_filter(pdf)
	allfiles = Gtk::FileFilter.new
	allfiles.name = _("All files")
	allfiles.add_pattern("*")
	dialog.add_filter(allfiles)
	# Action
	if dialog.run == Gtk::Dialog::RESPONSE_ACCEPT
		filename = dialog.filename
	else
		filename = nil
	end
	dialog.destroy
	# End
	return filename
end

# Write metadata to PDF file
def write_file (title, author, creator, producer, currentfile, outputfile = currentfile)
	if outputfile == nil
		return false
	end
	f = Tempfile.new('pdfmetaedit')
	f.puts "InfoKey: Title"
	f.puts "InfoValue: #{title}"
	f.puts "InfoKey: Author"
	f.puts "InfoValue: #{author}"
	f.puts "InfoKey: Creator"
	f.puts "InfoValue: #{creator}"
	f.puts "InfoKey: Producer"
	f.puts "InfoValue: #{producer}"
	f.close
	willend = false
	updateinfo	= "pdftk '#{currentfile}' update_info '#{f.path}' output '#{f.path}.pdf'"
	createidir	= "pdftk '#{currentfile}' cat output '#{f.path}.pdf'"
	mv			= "mv '#{f.path}.pdf' '#{outputfile}'"
	system(updateinfo+" || ("+createidir+" && "+mv+" && "+updateinfo+") && "+mv)
	if $?.exitstatus == 0
		dialog = Gtk::MessageDialog.new(@window, 
										Gtk::Dialog::MODAL,
										Gtk::MessageDialog::INFO,
										Gtk::MessageDialog::BUTTONS_YES_NO,
								_("Metadata written successfully") )
		dialog.title = _("Success")
		dialog.secondary_text = _("Continue editing the source file?")
		dialog.run do |response|
			if response == Gtk::Dialog::RESPONSE_NO
				willend = true
			end
			dialog.destroy
		end
	else
		error_window(_("Well, it seems something went wrong."))
	end
	return willend
end

# Start
if !ARGV[0]
	currentfile = open_file
elsif isPDF(ARGV[0])
	currentfile = ARGV[0]
else
	error_window(ARGV[0] + _(" is not a PDF document."))
	currentfile = open_file
end

if !currentfile
	exit 1
end

metadata = `pdftk '#{currentfile}' dump_data`

# Row title
labels = Gtk::VBox.new(false,5)
fields = Gtk::VBox.new(false,5)

titlelabel = Gtk::Label.new(_("_Title:"), true)
titlefield = Gtk::Entry.new
titlelabel.mnemonic_widget = titlefield
titlefield.width_chars = 60
titlefield.text = coder.decode(`echo -n '#{metadata}' | sed -n '/InfoKey: Title/,/InfoValue:/p' | tail -1`.chomp.gsub("InfoValue: ", ""))
labels.pack_start_defaults(titlelabel)
fields.pack_start_defaults(titlefield)

# Row metadata
authorlabel = Gtk::Label.new(_("Autho_r:"), true)
authorfield = Gtk::Entry.new
authorlabel.mnemonic_widget = authorfield
authorfield.text = coder.decode(`echo -n '#{metadata}' | sed -n '/InfoKey: Author/,/InfoValue:/p' | tail -1`.chomp.gsub("InfoValue: ", ""))
labels.pack_start_defaults(authorlabel)
fields.pack_start_defaults(authorfield)

# Row creator
creatorlabel = Gtk::Label.new(_("_Creator:"), true)
creatorfield = Gtk::Entry.new
creatorlabel.mnemonic_widget = creatorfield
creatorfield.text = coder.decode(`echo -n '#{metadata}' | sed -n '/InfoKey: Creator/,/InfoValue:/p' | tail -1`.chomp.gsub("InfoValue: ", ""))
labels.pack_start_defaults(creatorlabel)
fields.pack_start_defaults(creatorfield)

# Row producer
producerlabel = Gtk::Label.new(_("_Producer:"), true)
producerfield = Gtk::Entry.new
producerlabel.mnemonic_widget = producerfield
producerfield.text = coder.decode(`echo -n '#{metadata}' | sed -n '/InfoKey: Producer/,/InfoValue:/p' | tail -1`.chomp.gsub("InfoValue: ", ""))
labels.pack_start_defaults(producerlabel)
fields.pack_start_defaults(producerfield)

rowmetadata = Gtk::HBox.new(false,5)
rowmetadata.pack_start_defaults(labels)
rowmetadata.pack_start_defaults(fields)

# Row save
savebutton = Gtk::Button.new(Gtk::Stock::SAVE)
savebutton.signal_connect("clicked") {
	if write_file(titlefield.text, authorfield.text, creatorfield.text, producerfield.text, currentfile)
		Gtk.main_quit
	end
}
saveasbutton = Gtk::Button.new(Gtk::Stock::SAVE_AS)
saveasbutton.signal_connect("clicked") {
	if write_file(titlefield.text, authorfield.text, creatorfield.text, producerfield.text, currentfile, output_file(`dirname '#{currentfile}'`.chomp))
		Gtk.main_quit
	end
}
rowsave = Gtk::HBox.new(false,5)
rowsave.pack_start_defaults(savebutton)
rowsave.pack_start_defaults(saveasbutton)

# Packing together
vbox = Gtk::VBox.new(false,5)
vbox.pack_start_defaults(rowmetadata)
vbox.pack_start_defaults(rowsave)

# Main window initialization
@window = Gtk::Window.new
@window.add(vbox)
@window.border_width = 5
@window.set_title(`basename '#{currentfile}'`.chomp + " - pdfmetaedit")
@window.show_all
@window.signal_connect("destroy") { Gtk.main_quit }

Gtk.main
