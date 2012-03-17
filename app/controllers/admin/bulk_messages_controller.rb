class Admin::BulkMessagesController < Admin::AdminControllerBase

  def new
    @bulk_message = BulkMessage.new()
  end

  def create
    @bulk_message = BulkMessage.new(params[:bulk_message])

    if @bulk_message.valid? then
      @file, @rows, @invalid_rows, @unknown, @bulk_message = upload_file_helper(@bulk_message)

      if @invalid_rows == 10 then
        # Bad input file
        flash[:error]  = "Unable to find a field with hex IDs in the first 10 lines of this file. Is it a CSV file?"
        render :action => 'new'
        return
      else
        flash[:info] = "
        <table>
          <tr><td>Uploaded file:</td><td>#{@file.original_filename}</td></tr>
          <tr><td>Rows found (including header):</td><td>#{@rows}</td></tr>
          <tr><td>Rows without hex id:</td><td>#{@invalid_rows}</td></tr>
          <tr><td>Users found:</td><td>#{@bulk_message.recipients.size}</td></tr>
          <tr><td>Unknown users:</td><td>#{@unknown.size}</td></tr>
        </table>"
      end
      @bulk_message.save()

      flash[:notice] = "Message prepared"
      #redirect_to admin_bulk_messages_send_url
      redirect_to admin_bulk_messages_url
      return
    else
      render :action => 'new'
      return
    end
  end

  def index
    @bulk_messages = BulkMessage.order('created_at desc').all
  end

  def edit
    @bulk_message = BulkMessage.find(params[:id])
  end

  def update
    @bulk_message = BulkMessage.find(params[:id])

    if @bulk_message.valid? then

      if not params[:bulk_message]['recipients_file'].nil? then
        @file, @rows, @invalid_rows, @unknown, @bulk_message = upload_file_helper(@bulk_message)

        if @invalid_rows == 10 then
          # Bad input file
          flash[:error]  = "Unable to find a field with hex IDs in the first 10 lines of this file. Is it a CSV file?"
          render :action => 'new'
          return
        else
          flash[:info] = "
        <table>
          <tr><td>Uploaded file:</td><td>#{@file.original_filename}</td></tr>
          <tr><td>Rows found (including header):</td><td>#{@rows}</td></tr>
          <tr><td>Rows without hex id:</td><td>#{@invalid_rows}</td></tr>
          <tr><td>Users found:</td><td>#{@bulk_message.recipients.size}</td></tr>
          <tr><td>Unknown users:</td><td>#{@unknown.size}</td></tr>
        </table>"
        end
      end

      @bulk_message.save()

      flash[:notice] = "Message prepared"
      #redirect_to admin_bulk_messages_send_url
      redirect_to admin_bulk_messages_url
      return
    else
      render :action => 'new'
      return
    end

  end

  def show
    @bulk_message = BulkMessage.find(params[:id])
  end

  def recipients
    @bulk_message = BulkMessage.find(params[:id])
  end

  def send_message
    @bulk_message = BulkMessage.find(params[:id])
    if @bulk_message.recipients.size == 0 then
      flash[:error] = "Please add some recipients before sending this message."
      redirect_to admin_bulk_messages_url
      return
    end
    if @bulk_message.sent then
      flash[:error] = "Message was already sent, not re-sent."
      redirect_to admin_bulk_messages_url
      return
    end

    @bulk_message.recipients.each do |user|
      begin
        UserMailer.bulk_message(@bulk_message,user).deliver
        user.log("Bulk message with id #{@bulk_message.id} (#{@bulk_message.subject}) sent to #{user.email}")
      rescue Exception => e
        user.log("Bulk message with id #{@bulk_message.id} (#{@bulk_message.subject}) could not be sent to #{user.email}: #{e.inspect()}")
      end
    end

    @bulk_message.sent = true
    @bulk_message.sent_at = Time.now()
    @bulk_message.save!

    flash[:notice] = "Message sent. Please check the user log for delivery errors."
    redirect_to admin_bulk_messages_url
  end

private

  def upload_file_helper(bulk_message)
    @file = params[:bulk_message]['recipients_file']

    @bulk_message = bulk_message

    @invalid_rows = 0
    @rows = 0
    @hex_id_column = nil
    @parsed_file=CSV::Reader.parse(@file.read)
    @unknown = Array.new()
    @parsed_file.each  do |row|
      break if @invalid_rows == 10
      if not @hex_id_column.nil? then
        if not User.find_by_hex(row[@hex_id_column]).nil? then
          @bulk_message.bulk_message_recipients << BulkMessageRecipient.new(:user_id => User.find_by_hex(row[@hex_id_column]).id)
        else
          # Hmm, user not found
          @unknown.push(row)
        end
      else
        @item_position = 0
        row.each do |item|
          if item =~ /^..[0-9a-f]{6}$/i then
            @hex_id_column = @item_position
            @bulk_message.bulk_message_recipients = []
            @bulk_message.bulk_message_recipients << BulkMessageRecipient.new(:user_id => User.find_by_hex(row[@hex_id_column]).id)
          end
          @item_position += 1
        end
        @invalid_rows += 1 if @hex_id_column.nil?
      end
      @rows += 1
    end
    return @file, @rows, @invalid_rows, @unknown, @bulk_message
  end

end

