module SignatureDetection

=begin

try to detect the signature in list of articles for example

  signature = SignatureDetection.find_signature(string_list)

returns

  signature = '...signature possible match...'

=end

  def self.find_signature(string_list)

    # hash with possible signature and count of matches in string list
    possible_signatures = {}

    # loop all strings in array
    ( 0..string_list.length - 1 ).each {|main_string_index|
      break if main_string_index + 1 > string_list.length - 1

      # loop all all strings in array except of the previous index
      ( main_string_index + 1..string_list.length - 1 ).each {|second_string_index|

        # get content of string 1
        string1_content = string_list[main_string_index]

        # get content of string 2
        string2_content = string_list[second_string_index]

        # diff strings
        diff_result = Diffy::Diff.new(string1_content, string2_content)

        # split diff result by new line
        diff_result_array = diff_result.to_s.split("\n")

        # define start index for blocks with no difference
        match_block = nil

        # loop of lines of the diff result
        ( 0..diff_result_array.length - 1 ).each {|diff_string_index|

          # if no block with difference is defined then we try to find a string block without a difference
          if !match_block
            match_block = diff_string_index
          end

          # get line of diff result with current loop inde
          line = diff_result_array[diff_string_index]

          # check if the line starts with
          # + = new content incoming
          # - = removed content
          # \ = end of file
          # or if the current line is the last line of the diff result
          next if line !~ /^(\\|\+|\-)/i && diff_string_index != diff_result_array.length - 1

          # if the count of the lines without any difference is higher than 5 lines
          if diff_string_index - match_block > 5

            # define the block size without any difference
            # except "-" because in this case 1 line is removed to much
            match_block_total = diff_string_index + (line =~ /^(\\|\+)/i ? -1 : 0)

            # get string of possible signature
            match_content = ''
            ( match_block..match_block_total ).each {|match_block_index|
              match_content += "#{diff_result_array[match_block_index][1..-1]}\n"
            }

            # count the match of the signature in string list to rank
            # the signature
            possible_signatures[match_content] ||= 0
            possible_signatures[match_content] += 1

            break
          end

          match_block = nil
        }
      }
    }

    # loop all possible signature by rating and return highest rating
    possible_signatures.sort { |a1, a2| a2[1].to_i <=> a1[1].to_i }.map do |content, _score|
      return content.chomp
    end

    nil
  end

=begin

this function will search for a signature string in a string (e.g. article) and return the line number of the signature start

  signature_line = SignatureDetection.find_signature_line(signature, string)

returns

  signature_line = 123

  or

  signature_line = nil

=end

  def self.find_signature_line(signature, string)

    # try to find the char position of the signature
    search_position = string.index(signature)

    return if search_position.nil?

    # count new lines up to signature
    string[0..search_position].split("\n").length + 1
  end

=begin

this function will search for a signature string in all articles of a given user_id

  signature = SignatureDetection.by_user_id(user_id)

returns

  signature = '...signature possible match...'

=end

  def self.by_user_id(user_id)

    article_type = Ticket::Article::Type.lookup(name: 'email')
    article_bodies = []
    tickets = Ticket.where(created_by_id: user_id, create_article_type_id: article_type.id).limit(10).order(id: :desc)
    tickets.each {|ticket|
      article = ticket.articles.first
      article_bodies.push article.body
    }

    find_signature( article_bodies )
  end

=begin

rebuild signature for each user

  SignatureDetection.rebuild_all_user

returns

  true/false

=end

  def self.rebuild_all_user

    User.select('id').where(active: true).each {|local_user|

      signature_detection = by_user_id(local_user.id)
      next if !signature_detection

      user = User.find(local_user.id)
      next if user.preferences[:signature_detection] == signature_detection

      user.preferences[:signature_detection] = signature_detection
      user.save
    }
    true
  end

=begin

rebuild signature for all articles

  SignatureDetection.rebuild_all_articles

returns

  true/false

=end

  def self.rebuild_all_articles

    Ticket::Article.all.each {|article|

      user = User.find(article.created_by_id)
      next if !user.preferences[:signature_detection]

      signature_line = find_signature_line(user.preferences[:signature_detection], article.body)
      next if !signature_line
      next if article.preferences[:signature_detection] == signature_line

      article.preferences[:signature_detection] = signature_line
      article.save
    }
    true
  end

end