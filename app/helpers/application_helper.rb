module ApplicationHelper
  def get_grouped_orgs
    {
        "Vendor" => Vendor.all.collect {|vendor| [vendor.vendor_name, vendor.id.to_s + '-vendor']},
        "Sponsor Agency" => SponsorAgency.all.collect {|sponsor| [sponsor.sponsor_name, sponsor.id.to_s + '-sponsor']}
    }
  end
end
