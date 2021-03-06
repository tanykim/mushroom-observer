# encoding: utf-8
require "test_helper"

class SupportControllerTest < FunctionalTestCase
  # Replace this with your real tests.
  def test_donors
    get_with_dump(:donors)
    assert_template(:donors)
  end

  def test_donate
    get_with_dump(:donate)
    assert_template(:donate)
  end

  def confirm_post(amount, other_amount)
    donations = Donation.count
    anon = false
    final_amount = (amount == "other") ? other_amount : amount
    params = {
      donation: {
        amount: amount,
        other_amount: other_amount,
        who: rolf.name,
        email: rolf.email,
        anonymous: anon
      }
    }
    post(:confirm, params)
    assert_template(:confirm)
    assert_equal(donations + 1, Donation.count)
    donation = Donation.all.order("created_at DESC")[0]
    assert_equal(final_amount, donation.amount)
    assert_equal(rolf.name, donation.who)
    assert_equal(rolf.email, donation.email)
    assert_equal(anon, donation.anonymous)
    assert_equal(false, donation.reviewed)
  end

  def test_confirm_post
    confirm_post(25, 0)
  end

  def test_confirm_other_amount_post
    confirm_post("other", 30)
  end

  def test_create_donation
    get(:create_donation)
    assert_response(:redirect)

    make_admin
    get_with_dump(:create_donation)
    assert_template(:create_donation)
  end

  def create_donation_post(anon)
    make_admin
    amount = 100.00
    donations = Donation.count
    params = {
      donation: {
        amount: amount,
        who: rolf.name,
        email: rolf.email,
        anonymous: anon
      }
    }
    post(:create_donation, params)
    assert_equal(donations + 1, Donation.count)
    donation = Donation.all.order("created_at DESC")[0]
    assert_equal(amount, donation.amount)
    assert_equal(rolf.name, donation.who)
    assert_equal(rolf.email, donation.email)
    assert_equal(anon, donation.anonymous)
    assert_equal(true, donation.reviewed)
    assert_equal(rolf, donation.user)
  end

  def test_create_donation_post
    create_donation_post(false)
  end

  def test_create_donation_anon_post
    create_donation_post(true)
  end

  def test_review_donations
    get(:review_donations)
    assert_response(:redirect)

    make_admin
    get_with_dump(:review_donations)
    assert_template(:review_donations)
  end

  def test_review_donations_post
    make_admin
    unreviewed = donations(:unreviewed)
    assert_equal(false, unreviewed.reviewed)
    params = {
      reviewed: {
        unreviewed.id => true
      }
    }
    post(:review_donations, params)
    reloaded = Donation.find(unreviewed.id)
    assert(reloaded.reviewed)
  end

  def test_letter
    get_with_dump(:letter)
    assert_template(:letter)
  end
end
