require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(phone_number)
  phone_number = phone_number.to_s.scan(/\d/).join('')
  return phone_number if phone_number.length == 10
  return 'Invalid Number' if phone_number.length < 10
  if phone_number.length == 11
    unless phone_number[0] == '1'
      return 'Invalid Number'
    else
      return phone_number.slice(0, 0)
    end
  else
    return 'Invalid Number'
  end
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exists?('output')

  filename = "output/thanks_#{id}"

  File.open(filename, "w") do |file|
    file.puts form_letter
  end
end

def gather_registration_data(reg_date, reg_hours, reg_days)
  reg_hours.push(reg_date[:hour])
  reg_days.push(Date.new(reg_date[:year], reg_date[:mon], reg_date[:mday]).wday)
end

def reg_data_analysis(reg_hours, reg_days)
  hour_analysis = reg_hours.reduce(Hash.new()) do |hour_counter, hour|
    hour_counter[:"hour_#{hour}"] ||= 0
    hour_counter[:"hour_#{hour}"] += 1
    hour_counter
  end
  
  reg_days = reg_days.map do |day|
    case day
    when 0
      day = "Sunday"
    when 1
      day = "Monday"
    when 2
      day = "Tuesday"
    when 3
      day = "Wednesday"
    when 4
      day = "Thursday"
    when 5
      day = "Friday"
    when 6
      day = "Saturday"
    end
  end

  day_analysis = reg_days.reduce(Hash.new()) do |day_counter, day|
    day_counter[day] ||= 0
    day_counter[day] += 1
    day_counter
  end
  return [hour_analysis, day_analysis]
end

def save_registration_data(reg_data_template)
  Dir.mkdir('registration_data') unless Dir.exists?('registration_data')

  filename = "registration_data/data"

  File.open(filename, "w") do 
    |file| file.puts reg_data_template
  end
end

puts 'Event Manager Initialized!'

contents = CSV.open(
  'event_attendees.csv', 
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_letter_template = ERB.new template_letter

reg_hours = []
reg_days = []

contents.each do |row|
  id = row[:id]
  name = row[:first_name]
  phone_number = clean_phone_number(row[:homephone])

  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_letter_template.result(binding)
  
  save_thank_you_letter(id, form_letter)

  gather_registration_data(Date._strptime(row[:regdate], '%m/%d/%Y %H:%M'), reg_hours, reg_days)
end

template_data = File.read('registration_data.erb')
erb_data_template = ERB.new template_data

hour_analysis, day_analysis = reg_data_analysis(reg_hours, reg_days)

reg_data_template = erb_data_template.result(binding)

save_registration_data(reg_data_template)