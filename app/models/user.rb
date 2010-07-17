require 'digest/sha1'

class User < ActiveRecord::Base
  validates_presence_of      :name
  validates_uniqueness_of    :name

  attr_accessor :password_confirmation
  validates_confirmation_of :password

  validate :password_non_blank, :valid_email

  def before_save
    self.name.downcase!
  end

  def self.authenticate(name, password)
    user = self.find_by_name(name)
    if user
      expected_password = encrypted_password(password, user.salt)
      if user.hashed_password != expected_password
        user = nil
      end
    end
    user
  end


  def password
    @password
  end
  
  def password=(pwd)
    @password = pwd
    return if pwd.blank?
    create_new_salt
    self.hashed_password = User.encrypted_password(self.password, self.salt)
  end



private 

  def valid_email
    if Person.find(:all, :conditions => ["email = ?", name]).empty? 
      errors.add(:email, " - Your Email address is not on file.\n 
                             Please contact Brother Kinateder to create an account")
    end
  end

  def password_non_blank
    errors.add(:password, " - Missing password") if hashed_password.blank?
  end

  def self.encrypted_password(password, salt)
    string_to_hash = password + "shark" + salt
    Digest::SHA1.hexdigest(string_to_hash)
  end

  def create_new_salt
    self.salt = self.object_id.to_s + rand.to_s
  end


end