resource aws_key_pair server {
  key_name = "${var.role}${var.id}-greg-backdoor"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDY1d1L3iKHbv1Ivn2zYxdmaohSFwHb4l1lUp+yso1fhvRxJ0NqxLM34vmyRvwNwbukdRSiC84QbQ9Bxl4TuU3H+Gbxs1xfhVIhyRrHwEp8hp6U1pfuG29NtzUwViRxvHKv/HF7sLcA/1ks9ZD0prqP6UkDkivcrlV4iXVEcRCsuhoWYqnOiq93SPTMY5S0CA1jt69+zz07K+QN/TUrgua3TROlWksdGuv35zcf7TIWZIkEElK7HCe6EnhLq3hEe5XgqGIuzDMh/D1rPZ5mBq+YPc1x9f+Y+NPm08UD1WS3OJzPNvHYHYwx6mVnrlwN3AyK5+d7wsSv6fNA2vGqAz/5 greg-backdoor"
}
